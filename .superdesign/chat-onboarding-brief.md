# Lumi Coach and student welcome review

Keep the approved warm paper and sage visual system and existing workspace structure. This is a design prototype for review, not a live AI chat.

## Chat
- Replace the circular reload icon with a visible New Chat button, plus icon optional. No trash/delete action in the chat header. Keep Close.
- DM Sans throughout the chat header, welcome and messages; normal sentence case for speaker labels. Body 14-15px, line-height 1.6-1.7, readable contrast and generous space. No serif in chat.
- You and Lumi Coach sit ABOVE and OUTSIDE each bubble. You align right; Lumi Coach align left. Quiet sage user bubbles and warm white assistant bubbles; avoid heavy card borders.
- Keep the composer fixed to the drawer bottom and the live width control. Main-screen content remains the real workspace.
- Mock reply addresses fictional student Ananya by name: Ananya, I created your Quantum Mechanics note. The note is already open in the main screen.
- New Chat clears the prototype conversation and shows Hello, Ananya. What would you like to explore?

## Recent chat options
- Right click a Recent chat row opens Open chat and Delete chat options. Also offer keyboard Context Menu / Shift+F10 and a small row overflow menu as touch and discoverability fallback. No delete button inside the chat screen.
- Delete chat asks for confirmation, and removes the selected prototype chat only on confirmation. Cancel leaves it. These are sample data, not real chats.

## First launch
- Centered, focused student welcome screen before the workspace, with the existing Lumi logo. Welcome to Lumi. A little about you.
- Required explicitly labeled fields: Name, Class, School name, each maximum 80 printable characters. Use placeholders, do not prefill real personal information. Button: Start learning.
- Explain: Saved in your local Lumi workspace. Lumi uses these details with your configured AI provider to personalize your chats.
- Save only after valid fields; show progress, save-error/retry behavior in design notes. Returning users bypass onboarding. Name, class and school remain editable in Settings / General.
- After form submission transition to the chat preview and use the entered name in the welcome. Store only in prototype memory, no backend or localStorage calls.

## Preview
One desktop prototype with a clearly separated small review toolbar: Chat, Chat options, First launch. Toolbar is preview navigation only, not product UI. Include all three states inside the same HTML draft with simple functional state switching. Default Chat with main note open and drawer visible. Chat options view opens contextual menu for sample Recent chat so deletion is reviewable; First launch view shows the profile form. Keep responsive behavior and no horizontal overflow at 375px.
