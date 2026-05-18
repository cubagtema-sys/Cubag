/**
 * Consistent mapping of backend user object to frontend user object.
 */
export const mapUser = (backendUser, existingUser = {}) => {
  const photo = backendUser.profile_photo || backendUser.photo || existingUser.photo || null;

  const mapped = {
    ...existingUser,
    ...backendUser,
    id: backendUser.id || existingUser.id || existingUser.memberId,
    memberId: backendUser.id || existingUser.id || existingUser.memberId,
    name: backendUser.name || existingUser.name,
    email: backendUser.email || existingUser.email,
    role: backendUser.role || backendUser.member_type || existingUser.role,
    status: backendUser.status || existingUser.status,
    photo: photo,
    profile_photo: photo,
    licenseExpiry: backendUser.license_number || backendUser.licenseNumber || backendUser.license_expiry_date || existingUser.licenseExpiry || 'No Active License'
  };

  // Ensure email-specific persistence for photos
  if (mapped.photo && mapped.email) {
    localStorage.setItem(`cubag_photo_${mapped.email}`, mapped.photo);
  }

  return mapped;
};

export const getStoredUser = () => {
  try {
    const stored = localStorage.getItem('cubag_user');
    if (!stored) return null;
    let user = JSON.parse(stored);

    // Fallback for photo from email-specific storage
    if (!user.photo && user.email) {
      const savedPhoto = localStorage.getItem(`cubag_photo_${user.email}`);
      if (savedPhoto) user.photo = savedPhoto;
    }

    return user;
  } catch (e) {
    return null;
  }
};

export const saveUser = (user) => {
  localStorage.setItem('cubag_user', JSON.stringify(user));
};
