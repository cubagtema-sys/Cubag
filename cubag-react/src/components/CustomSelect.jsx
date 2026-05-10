import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'

export default function CustomSelect({ options, value, onChange, label, icon }) {
  const [isOpen, setIsOpen] = useState(false)
  const [dropPos, setDropPos] = useState({ top: 0, left: 0, width: 0 })
  const triggerRef = useRef(null)
  const dropdownRef = useRef(null)

  // Close when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (
        triggerRef.current && !triggerRef.current.contains(event.target) &&
        dropdownRef.current && !dropdownRef.current.contains(event.target)
      ) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Recalculate position on scroll/resize so it tracks the trigger
  useEffect(() => {
    if (!isOpen) return
    function updatePos() {
      if (!triggerRef.current) return
      const rect = triggerRef.current.getBoundingClientRect()
      setDropPos({ top: rect.bottom + 6, left: rect.left, width: rect.width })
    }
    updatePos()
    window.addEventListener('scroll', updatePos, true)
    window.addEventListener('resize', updatePos)
    return () => {
      window.removeEventListener('scroll', updatePos, true)
      window.removeEventListener('resize', updatePos)
    }
  }, [isOpen])

  const handleOpen = () => {
    if (triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect()
      setDropPos({ top: rect.bottom + 6, left: rect.left, width: rect.width })
    }
    setIsOpen(prev => !prev)
  }

  const selectedOption = options.find(opt => opt.value === value) || options[0]
  const isPlaceholder = !value || selectedOption?.disabled

  return (
    <div className="custom-select-container" ref={triggerRef}>
      {label && <label className="custom-select-label">{label}</label>}

      <div
        className={`custom-select-trigger ${isOpen ? 'open' : ''}`}
        onClick={handleOpen}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {icon && <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: isPlaceholder ? 'var(--text-muted)' : 'var(--brand-primary)' }}>{icon}</span>}
          <span style={{ color: isPlaceholder ? 'var(--text-muted)' : 'var(--text-primary)' }}>{selectedOption.label}</span>
        </div>
        <span className="material-symbols-outlined trigger-arrow">expand_more</span>
      </div>

      {isOpen && createPortal(
        <div
          ref={dropdownRef}
          className="custom-select-options"
          style={{
            position: 'fixed',
            top: dropPos.top,
            left: dropPos.left,
            width: dropPos.width,
            zIndex: 99999,
          }}
        >
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
        </div>,
        document.body
      )}
    </div>
  )
}
