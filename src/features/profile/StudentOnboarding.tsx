import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowRight } from 'lucide-react'
import { lumiQueryKeys, saveApplicationSettings, type LumiApplicationSettings } from '../../lib/lumi-api'
import { hasStudentProfile, readStudentProfile } from './student-profile'
import './student-profile.css'

export function StudentOnboarding({ settings }: { settings: LumiApplicationSettings }) {
  const client = useQueryClient()
  const [profile, setProfile] = useState(() => readStudentProfile(settings))
  const save = useMutation({
    mutationFn: async () => {
      const saved = await saveApplicationSettings({
        displayName: profile.name.trim(), studentClass: profile.studentClass.trim(),
        schoolName: profile.schoolName.trim(), studentProfileCompleted: true,
      })
      if (!hasStudentProfile(saved)) throw new Error('The local service could not save your student profile. Update or restart the Lumi backend and try again.')
      return saved
    },
    onSuccess: (saved) => client.setQueryData(lumiQueryKeys.settings, saved),
  })
  const fields = [
    { key: 'name', label: 'Name', placeholder: 'e.g. Ananya', autoComplete: 'given-name' },
    { key: 'studentClass', label: 'Class', placeholder: 'e.g. Class 10', autoComplete: 'off' },
    { key: 'schoolName', label: 'School name', placeholder: 'e.g. Greenfield School', autoComplete: 'organization' },
  ] as const
  return <main className="student-welcome" aria-labelledby="student-welcome-title">
    <div className="student-welcome-content">
      <header><img src="/lumi-mark.svg" width={56} height={56} alt="Lumi" /><h1 id="student-welcome-title">Welcome to Lumi.</h1><p>A little about you.</p></header>
      <form className="student-profile-form" onSubmit={(event) => { event.preventDefault(); if (Object.values(profile).every((value) => value.trim())) save.mutate() }}>
        {fields.map((field, index) => <label key={field.key} htmlFor={`student-${field.key}`}>{field.label}<input id={`student-${field.key}`} name={field.key} value={profile[field.key]} onChange={(event) => { setProfile((current) => ({ ...current, [field.key]: event.target.value })); save.reset() }} maxLength={80} required autoFocus={index === 0} autoComplete={field.autoComplete} placeholder={field.placeholder} disabled={save.isPending} /></label>)}
        <p>Saved in your local Lumi workspace. Lumi uses these details with your configured AI provider to personalize your chats. You can edit them in Settings → General.</p>
        {save.isError && <p className="student-profile-error" role="alert">{save.error instanceof Error ? save.error.message : 'Could not save your details. Please try again.'}</p>}
        <button type="submit" disabled={save.isPending || Object.values(profile).some((value) => !value.trim())}>{save.isPending ? 'Saving your details…' : 'Start learning'}<ArrowRight aria-hidden="true" size={18} /></button>
      </form>
    </div>
  </main>
}
