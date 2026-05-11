import { useState, useRef, useEffect, useCallback } from 'react'
import { createPortal } from 'react-dom'

export default function CustomSelect({ options, value, onChange, label, icon }) {
  const [isOpen, setIsOpen] = useState(false)
  const [dropPos, setDropPos] = useState({ top: 0, left: 0, width: 0 })
  const triggerRef = useRef(null)
  const dropdownRef = useRef(null)

  // Close when clicking/tapping outside
  useEffect(() => {
    if (!isOpen) return

    function handleOutside(event) {
      if (
        triggerRef.current && !triggerRef.current.contains(event.target) &&
        dropdownRef.current && !dropdownRef.current.contains(event.target)
      ) {
        setIsOpen(false)
      }
    }

    // Small delay so the opening tap doesn't immediately trigger close
    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handleOutside)
      document.addEventListener('touchstart', handleOutside)
    }, 50)

    return () => {
      clearTimeout(timer)
      document.removeEventListener('mousedown', handleOutside)
      document.removeEventListener('touchstart', handleOutside)
    }
  }, [isOpen])

  // Recalculate position on scroll/resize so it tracks the trigger
  const updatePos = useCallback(() => {
    if (!triggerRef.current) return
    const rect = triggerRef.current.getBoundingClientRect()
    const spaceBelow = window.innerHeight - rect.bottom
    const spaceAbove = rect.top
    
    let newPos = { left: rect.left, width: rect.width }
    if (spaceBelow < 250 && spaceAbove > spaceBelow) {
      newPos.bottom = window.innerHeight - rect.top + 6
      newPos.maxHeight = spaceAbove - 20
    } else {
      newPos.top = rect.bottom + 6
      newPos.maxHeight = spaceBelow - 20
    }
    setDropPos(newPos)
  }, [])

  useEffect(() => {
    if (!isOpen) return
    updatePos()
    window.addEventListener('scroll', updatePos, true)
    window.addEventListener('resize', updatePos)
    return () => {
      window.removeEventListener('scroll', updatePos, true)
      window.removeEventListener('resize', updatePos)
    }
  }, [isOpen, updatePos])

  const handleOpen = (e) => {
    e.preventDefault()
    e.stopPropagation()
    updatePos()
    setIsOpen(prev => !prev)
  }

  const handleSelect = (option) => {
    if (option.disabled) return
    onChange(option.value)
    setIsOpen(false)
  }

  const selectedOption = options.find(opt => opt.value === value) || options[0]
  const isPlaceholder = !value || selectedOption?.disabled

  return (
    <div className="custom-select-container" ref={triggerRef}>
      {label && <label className="custom-select-label">{label}</label>}

      <div
        className={`custom-select-trigger ${isOpen ? 'open' : ''}`}
        onClick={handleOpen}
        onTouchEnd={handleOpen}
        role="combobox"
        aria-expanded={isOpen}
        tabIndex={0}
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
            bottom: dropPos.bottom,
            left: dropPos.left,
            width: dropPos.width,
            maxHeight: dropPos.maxHeight ? Math.max(100, dropPos.maxHeight) : undefined,
            zIndex: 100000,
            animation: 'slideInDown 0.2s ease-out',
            overflowY: 'auto',
            WebkitOverflowScrolling: 'touch'
          }}
        >
          {options.map(option => (
            <div
              key={option.value || '__placeholder__'}
              className={`custom-select-option ${value === option.value ? 'selected' : ''} ${option.disabled ? 'disabled' : ''}`}
              onClick={(e) => { e.stopPropagation(); handleSelect(option) }}
              onTouchEnd={(e) => { e.preventDefault(); e.stopPropagation(); handleSelect(option) }}
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
