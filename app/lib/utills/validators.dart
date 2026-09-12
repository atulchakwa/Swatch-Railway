class AppValidators {
  static final RegExp _emailRegex = RegExp(r'^[\w\.-]+@[\w-]+(\.[\w-]+)+$');
  static final RegExp _mobileRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _aadhaarRegex = RegExp(r'^\d{12}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(v)) return 'Enter valid email';
    return null;
  }

  static String? mobile(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Mobile number is required' : null;
    if (!_mobileRegex.hasMatch(v)) return 'Enter valid 10-digit mobile number';
    return null;
  }

  static String? aadhaar(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Aadhaar number is required' : null;
    if (!_aadhaarRegex.hasMatch(v)) return 'Enter valid 12-digit Aadhaar number';
    return null;
  }
}