export function showToast(message, type = 'info') {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.style.position = 'fixed';
    container.style.bottom = '24px';
    container.style.right = '24px';
    container.style.zIndex = '9999';
    container.style.display = 'flex';
    container.style.flexDirection = 'column';
    container.style.gap = '10px';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  const bg = type === 'success' ? 'var(--brand-success)' : type === 'error' ? 'var(--brand-danger)' : 'var(--brand-primary)';
  toast.style.background = bg;
  toast.style.color = '#fff';
  toast.style.padding = '12px 20px';
  toast.style.borderRadius = 'var(--radius-md)';
  toast.style.boxShadow = 'var(--shadow-lg)';
  toast.style.fontWeight = '600';
  toast.style.fontSize = '0.9rem';
  toast.style.transition = 'all 0.3s ease';
  toast.style.transform = 'translateY(20px)';
  toast.style.opacity = '0';
  toast.style.display = 'flex';
  toast.style.alignItems = 'center';
  toast.style.gap = '8px';
  
  let icon = 'info';
  if (type === 'success') icon = 'check_circle';
  if (type === 'error') icon = 'error';

  toast.innerHTML = `<span class="material-symbols-outlined" style="font-size: 1.2rem;">${icon}</span> ${message}`;

  container.appendChild(toast);

  // Trigger reflow for animation
  requestAnimationFrame(() => {
    toast.style.transform = 'translateY(0)';
    toast.style.opacity = '1';
  });

  setTimeout(() => {
    toast.style.transform = 'translateY(20px)';
    toast.style.opacity = '0';
    setTimeout(() => {
      if (container.contains(toast)) {
        container.removeChild(toast);
      }
    }, 300);
  }, 3000);
}
