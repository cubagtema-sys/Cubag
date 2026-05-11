import { useState, useRef, useEffect } from 'react'

export default function CustomSelect({ options, value, onChange, label, icon }) {
  const [isOpen, setIsOpen] = useState(false)
  const containerRef = useRef(null)

  // Close when clicking/tapping outside
  useEffect(() => {
    if (!isOpen) return

    function handleOutside(event) {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false)
      }
    }

    document.addEventListener('mousedown', handleOutside)
    document.addEventListener('touchstart', handleOutside)

    return () => {
      document.removeEventListener('mousedown', handleOutside)
      document.removeEventListener('touchstart', handleOutside)
    }
  }, [isOpen])

  const handleToggle = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setIsOpen(prev => !prev)
  }

  const handleSelect = (option, e) => {
    e.preventDefault()
    e.stopPropagation()
    if (option.disabled) return
    onChange(option.value)
    setIsOpen(false)
  }

  const selectedOption = options.find(opt => opt.value === value) || options[0]
  const isPlaceholder = !value || selectedOption?.disabled

  return (
    <div className="custom-select-container" ref={containerRef} style={{ marginBottom: '20px' }}>
      {label && <label className="custom-select-label">{label}</label>}

      <div
        className={`custom-select-trigger ${isOpen ? 'open' : ''}`}
        onClick={handleToggle}
        onKeyUp={(e) => e.key === 'Enter' && handleToggle(e)}
        role="combobox"
        aria-expanded={isOpen}
        tabIndex={0}
        style={{ userSelect: 'none', WebkitTapHighlightColor: 'transparent' }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, pointerEvents: 'none' }}>
          {icon && <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: isPlaceholder ? 'var(--text-muted)' : 'var(--brand-primary)' }}>{icon}</span>}
          <span style={{ color: isPlaceholder ? 'var(--text-muted)' : 'var(--text-primary)' }}>{selectedOption.label}</span>
        </div>
        <span className="material-symbols-outlined trigger-arrow" style={{ pointerEvents: 'none' }}>expand_more</span>
      </div>

      {isOpen && (
        <div
          className="custom-select-options"
          style={{
            display: 'block',
            visibility: 'visible',
            opacity: 1,
            transform: 'none',
            zIndex: 999999,
            maxHeight: '200px', // Limit height to ensure it fits on screen
            overflowY: 'auto',  // Enable vertical scrolling
            boxShadow: '0 4px 20px rgba(0,0,0,0.15)',
            border: '1.5px solid var(--brand-primary)'
          }}
        >
          {options.map(option => (
            <div
              key={option.value || '__placeholder__'}
              className={`custom-select-option ${value === option.value ? 'selected' : ''} ${option.disabled ? 'disabled' : ''}`}
              onClick={(e) => handleSelect(option, e)}
              style={option.disabled ? { color: 'var(--text-muted)', cursor: 'default', fontStyle: 'italic', pointerEvents: 'none', opacity: 0.6 } : {}}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, pointerEvents: 'none' }}>
                {option.icon && <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', opacity: option.disabled ? 0.4 : 1 }}>{option.icon}</span>}
                {option.label}
              </div>
              {value === option.value && !option.disabled && <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', pointerEvents: 'none' }}>check</span>}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
