export function showToast(message, type = 'info') {
  let container = document.getElementById('toast-container');
  // Force re-create if old container has stale bottom positioning
  if (container && container.style.bottom) {
    container.remove();
    container = null;
  }
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.style.position = 'fixed';
    container.style.top = '24px';
    container.style.left = '50%';
    container.style.transform = 'translateX(-50%)';
    container.style.zIndex = '99999';
    container.style.display = 'flex';
    container.style.flexDirection = 'column';
    container.style.alignItems = 'center';
    container.style.gap = '10px';
    container.style.width = '90%';
    container.style.maxWidth = '420px';
    container.style.pointerEvents = 'none';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  const bg = type === 'success' ? 'linear-gradient(135deg, #10b981, #059669)'
           : type === 'error' ? 'linear-gradient(135deg, #ef4444, #dc2626)'
           : type === 'warning' ? 'linear-gradient(135deg, #f59e0b, #d97706)'
           : 'linear-gradient(135deg, #f08232, #e06820)';
  toast.style.background = bg;
  toast.style.color = '#fff';
  toast.style.padding = '14px 24px';
  toast.style.borderRadius = '14px';
  toast.style.boxShadow = '0 8px 32px rgba(0,0,0,0.25)';
  toast.style.fontWeight = '700';
  toast.style.fontSize = '0.9rem';
  toast.style.transition = 'all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)';
  toast.style.transform = 'translateY(-20px) scale(0.95)';
  toast.style.opacity = '0';
  toast.style.display = 'flex';
  toast.style.alignItems = 'center';
  toast.style.justifyContent = 'center';
  toast.style.gap = '10px';
  toast.style.width = '100%';
  toast.style.textAlign = 'center';
  toast.style.pointerEvents = 'auto';
  toast.style.backdropFilter = 'blur(8px)';
  
  let icon = 'info';
  if (type === 'success') icon = 'check_circle';
  if (type === 'error') icon = 'error';
  if (type === 'warning') icon = 'warning';

  toast.innerHTML = `<span class="material-symbols-outlined" style="font-size: 1.3rem;">${icon}</span> ${message}`;

  container.appendChild(toast);

  // Trigger reflow for slide-down animation
  requestAnimationFrame(() => {
    toast.style.transform = 'translateY(0) scale(1)';
    toast.style.opacity = '1';
  });

  // Stay visible for 5 seconds
  setTimeout(() => {
    toast.style.transform = 'translateY(-20px) scale(0.95)';
    toast.style.opacity = '0';
    setTimeout(() => {
      if (container.contains(toast)) {
        container.removeChild(toast);
      }
    }, 400);
  }, 5000);
}
