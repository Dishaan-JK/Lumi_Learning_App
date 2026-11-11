use std::env;
use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};

static STOP: AtomicBool = AtomicBool::new(false);
#[cfg(unix)] extern "C" fn stop_signal(_: i32) { STOP.store(true, Ordering::SeqCst); }
#[cfg(unix)] unsafe extern "C" { fn signal(sig: i32, handler: extern "C" fn(i32)) -> usize; }
#[cfg(windows)] extern "system" fn stop_signal(_: u32) -> i32 { STOP.store(true, Ordering::SeqCst); 1 }
#[cfg(windows)] #[link(name = "Kernel32")]
unsafe extern "system" { fn SetConsoleCtrlHandler(handler: Option<extern "system" fn(u32) -> i32>, add: i32) -> i32; }

static BACKEND: &[u8] = include_bytes!(env!("LUMI_BACKEND_BINARY"));
static ASSETS: &[(&str, &[u8])] = &[
    __LUMI_ASSET_ENTRIES__
];

fn home_dir() -> PathBuf {
    #[cfg(windows)] let home = env::var_os("USERPROFILE");
    #[cfg(not(windows))] let home = env::var_os("HOME");
    home.map(PathBuf::from).unwrap_or_else(env::temp_dir)
}
fn data_dir() -> PathBuf {
    if let Some(path) = env::var_os("LUMI_DATA_DIR") { return PathBuf::from(path); }
    #[cfg(windows)] { return env::var_os("LOCALAPPDATA").map(PathBuf::from).unwrap_or_else(|| home_dir().join("AppData/Local")).join("Lumi"); }
    #[cfg(target_os = "macos")] { return env::var_os("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|| home_dir().join("Library/Application Support")).join("Lumi"); }
    #[cfg(target_os = "linux")] { return env::var_os("XDG_DATA_HOME").map(PathBuf::from).unwrap_or_else(|| home_dir().join(".local/share")).join("lumi"); }
}
fn cache_dir() -> PathBuf {
    #[cfg(windows)] { return env::var_os("LOCALAPPDATA").map(PathBuf::from).unwrap_or_else(|| home_dir().join("AppData/Local")).join("Lumi/cache"); }
    #[cfg(target_os = "macos")] { return env::var_os("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|| home_dir().join("Library/Caches")).join("Lumi"); }
    #[cfg(target_os = "linux")] { return env::var_os("XDG_CACHE_HOME").map(PathBuf::from).unwrap_or_else(|| home_dir().join(".cache")).join("lumi-single"); }
}
#[cfg(unix)]
fn protect_directory(path: &Path) {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(path, fs::Permissions::from_mode(0o700)).expect("Could not protect Lumi's local files");
}
#[cfg(windows)] fn protect_directory(_: &Path) {}
#[cfg(windows)] fn backend_file_name() -> &'static str { "lumi-backend.exe" }
#[cfg(not(windows))] fn backend_file_name() -> &'static str { "lumi-backend" }
fn open_browser(url: &str) {
    #[cfg(target_os = "windows")]
    let command = Command::new("rundll32.exe").args(["url.dll,FileProtocolHandler", url]).stdout(Stdio::null()).stderr(Stdio::null()).spawn();
    #[cfg(target_os = "macos")]
    let command = Command::new("open").arg(url).stdout(Stdio::null()).stderr(Stdio::null()).spawn();
    #[cfg(target_os = "linux")]
    let command = Command::new("xdg-open").arg(url).stdout(Stdio::null()).stderr(Stdio::null()).spawn();
    let _ = command;
}
fn port() -> u16 {
    let listener = TcpListener::bind(("127.0.0.1", 0)).expect("Could not reserve a local port");
    listener.local_addr().unwrap().port()
}
fn backend_ready(port: u16) -> bool {
    if let Ok(mut stream) = TcpStream::connect(("127.0.0.1", port)) {
        let _ = stream.set_read_timeout(Some(Duration::from_millis(500)));
        let _ = stream.write_all(b"GET /api/notes HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n");
        let mut data = [0u8; 128];
        return stream.read(&mut data).map(|n| n > 0 && data[..n].windows(3).any(|w| w == b"200")).unwrap_or(false);
    }
    false
}
fn ensure_backend(backend_path: &Path, backend_port: u16, data: &Path, ui_port: u16) -> Child {
    let mut child = Command::new(backend_path)
        .env("PORT", backend_port.to_string())
        .env("LUMI_DATA_DIR", data)
        .env("LUMI_ALLOWED_ORIGINS", format!("http://127.0.0.1:{ui_port},http://localhost:{ui_port}"))
        .stdin(Stdio::null()).stdout(Stdio::inherit()).stderr(Stdio::inherit())
        .spawn().expect("Could not start the embedded Lumi backend");
    let deadline = Instant::now() + Duration::from_secs(45);
    while Instant::now() < deadline {
        if backend_ready(backend_port) { return child; }
        if let Ok(Some(status)) = child.try_wait() { panic!("Lumi backend exited during startup: {status}"); }
        thread::sleep(Duration::from_millis(250));
    }
    let _ = child.kill();
    panic!("Lumi backend did not start within 45 seconds");
}
fn read_request(stream: &mut TcpStream) -> Option<(String, String, Vec<(String,String)>, Vec<u8>)> {
    stream.set_read_timeout(Some(Duration::from_secs(30))).ok()?;
    let mut bytes = Vec::new();
    let mut buf = [0u8; 8192];
    let header_end;
    loop {
        let n = stream.read(&mut buf).ok()?;
        if n == 0 { return None; }
        bytes.extend_from_slice(&buf[..n]);
        if bytes.len() > 64 * 1024 * 1024 { return None; }
        if let Some(i) = bytes.windows(4).position(|w| w == b"\r\n\r\n") { header_end = i + 4; break; }
    }
    let header = String::from_utf8_lossy(&bytes[..header_end]);
    let mut lines = header.lines();
    let mut start = lines.next()?.split_whitespace();
    let method = start.next()?.to_string();
    let path = start.next()?.to_string();
    let mut headers = Vec::new();
    let mut body_len = 0usize;
    for line in lines {
        if let Some((key, value)) = line.split_once(':') {
            if key.eq_ignore_ascii_case("content-length") { body_len = value.trim().parse().unwrap_or(0); }
            headers.push((key.trim().to_ascii_lowercase(), value.trim().to_string()));
        }
    }
    if body_len > 60 * 1024 * 1024 { return None; }
    while bytes.len() - header_end < body_len {
        let n = stream.read(&mut buf).ok()?;
        if n == 0 { return None; }
        bytes.extend_from_slice(&buf[..n]);
    }
    let body = bytes[header_end..header_end + body_len].to_vec();
    Some((method, path, headers, body))
}
fn response(stream: &mut TcpStream, status: &str, content_type: &str, body: &[u8]) {
    let head = format!("HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nCache-Control: no-cache\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n", body.len());
    let _ = stream.write_all(head.as_bytes());
    let _ = stream.write_all(body);
}
fn proxy(stream: &mut TcpStream, method: &str, path: &str, headers: &[(String,String)], body: &[u8], backend_port: u16) {
    let Ok(mut backend) = TcpStream::connect(("127.0.0.1", backend_port)) else {
        response(stream, "502 Bad Gateway", "text/plain", b"Lumi backend is unavailable"); return;
    };
    let origin = headers.iter().find(|(k,_)| k == "origin").map(|(_,v)| v.as_str());
    let content_type = headers.iter().find(|(k,_)| k == "content-type").map(|(_,v)| v.as_str()).unwrap_or("application/octet-stream");
    let request = format!("{method} {path} HTTP/1.1\r\nHost: 127.0.0.1:{backend_port}\r\nConnection: close\r\nContent-Length: {}\r\nContent-Type: {content_type}\r\n{}\r\n", body.len(), origin.map(|o| format!("Origin: {o}\r\n")).unwrap_or_default());
    if backend.write_all(request.as_bytes()).is_err() || backend.write_all(body).is_err() {
        response(stream, "502 Bad Gateway", "text/plain", b"Could not forward request to Lumi backend"); return;
    }
    let _ = std::io::copy(&mut backend, stream);
}
fn serve(mut stream: TcpStream, backend_port: u16) {
    let Some((method, path, headers, body)) = read_request(&mut stream) else { return; };
    if method == "OPTIONS" { response(&mut stream, "204 No Content", "text/plain", b""); return; }
    if path.split('?').next().unwrap_or("").starts_with("/api/") {
        proxy(&mut stream, &method, &path, &headers, &body, backend_port); return;
    }
    let decoded = path.split('?').next().unwrap_or("/").replace("%20", " ");
    let relative = decoded.trim_start_matches('/');
    if relative.split('/').any(|part| part == "..") { response(&mut stream, "400 Bad Request", "text/plain", b"Invalid path"); return; }
    let asset_path = if relative.is_empty() { "index.html" } else { relative };
    if let Some((_, data)) = ASSETS.iter().find(|(name,_)| *name == asset_path) {
        let mime = if asset_path.ends_with(".html") { "text/html; charset=utf-8" } else if asset_path.ends_with(".js") { "text/javascript; charset=utf-8" } else if asset_path.ends_with(".css") { "text/css; charset=utf-8" } else if asset_path.ends_with(".svg") { "image/svg+xml" } else if asset_path.ends_with(".woff2") { "font/woff2" } else if asset_path.ends_with(".woff") { "font/woff" } else if asset_path.ends_with(".ttf") { "font/ttf" } else if asset_path.ends_with(".png") { "image/png" } else { "application/octet-stream" };
        response(&mut stream, "200 OK", mime, data);
    } else if !asset_path.contains('.') {
        let html = ASSETS.iter().find(|(name,_)| *name == "index.html").map(|(_,data)| *data).unwrap_or(b"Lumi app bundle is missing its index.");
        response(&mut stream, "200 OK", "text/html; charset=utf-8", html);
    } else {
        response(&mut stream, "404 Not Found", "text/plain", b"Not found");
    }
}
fn main() {
    #[cfg(unix)] unsafe { signal(2, stop_signal); signal(15, stop_signal); }
    #[cfg(windows)] unsafe { SetConsoleCtrlHandler(Some(stop_signal), 1); }
    let cache = cache_dir();
    fs::create_dir_all(&cache).expect("Could not create Lumi runtime cache");
    protect_directory(&cache);
    let backend_path = cache.join(backend_file_name());
    if fs::read(&backend_path).map(|bytes| bytes.as_slice() != BACKEND).unwrap_or(true) {
        fs::write(&backend_path, BACKEND).expect("Could not unpack embedded Lumi backend");
        #[cfg(unix)] {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&backend_path, fs::Permissions::from_mode(0o700)).expect("Could not mark backend executable");
        }
    }
    let data = data_dir();
    fs::create_dir_all(&data).expect("Could not create Lumi data directory");
    protect_directory(&data);
    let ui_listener = TcpListener::bind("127.0.0.1:0").expect("Could not start local Lumi web server");
    ui_listener.set_nonblocking(true).expect("Could not configure local web server");
    let ui_port = ui_listener.local_addr().unwrap().port();
    let backend_port = port();
    let mut backend = ensure_backend(&backend_path, backend_port, &data, ui_port);
    let url = format!("http://127.0.0.1:{ui_port}/");
    println!("Lumi is ready at {url}");
    println!("Local data: {}", data.display());
    println!("Press Ctrl+C to stop Lumi.");
    open_browser(&url);
    while !STOP.load(Ordering::SeqCst) {
        match ui_listener.accept() {
            Ok((stream,_)) => { thread::spawn(move || serve(stream, backend_port)); }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => thread::sleep(Duration::from_millis(40)),
            Err(_) => thread::sleep(Duration::from_millis(100)),
        }
        if STOP.load(Ordering::SeqCst) { break; }
        if let Ok(Some(status)) = backend.try_wait() { eprintln!("Lumi backend stopped unexpectedly: {status}"); break; }
    }
    let _ = backend.kill();
    let _ = backend.wait();
}
