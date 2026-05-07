import { useState, useRef, useEffect } from 'react'

export default function CustomSelect({ options, value, onChange, label, icon }) {
  const [isOpen, setIsOpen] = useState(false)
  const dropdownRef = useRef(null)

  // Close when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const selectedOption = options.find(opt => opt.value === value) || options[0]
  const isPlaceholder = !value || selectedOption?.disabled

  return (
    <div className="custom-select-container" ref={dropdownRef}>
      {label && <label className="custom-select-label">{label}</label>}
      
      <div 
        className={`custom-select-trigger ${isOpen ? 'open' : ''}`}
        onClick={() => setIsOpen(!isOpen)}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {icon && <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: isPlaceholder ? 'var(--text-muted)' : 'var(--brand-primary)' }}>{icon}</span>}
          <span style={{ color: isPlaceholder ? 'var(--text-muted)' : 'var(--text-primary)' }}>{selectedOption.label}</span>
        </div>
        <span className="material-symbols-outlined trigger-arrow">expand_more</span>
      </div>

      {isOpen && (
        <div className="custom-select-options">
          {options.map(option => (
            <div 
              key={option.value || '__placeholder__'}
              className={`custom-select-option ${value === option.value ? 'selected' : ''} ${option.disabled ? 'disabled' : ''}`}
              onClick={() => {
                if (option.disabled) return
                onChange(option.value)
                setIsOpen(false)
              }}
              style={option.disabled ? { color: 'var(--text-muted)', cursor: 'default', fontStyle: 'italic', pointerEvents: 'none', opacity: 0.6 } : {}}
            >
              {option.icon && <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', opacity: option.disabled ? 0.4 : 1 }}>{option.icon}</span>}
              {option.label}
              {value === option.value && !option.disabled && <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check</span>}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
