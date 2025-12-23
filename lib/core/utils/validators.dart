class Validators {
  static bool isValidEmail(String value) =>
      RegExp(r'^[\\w-.]+@([\\w-]+\\.)+[\\w-]{2,4}\$').hasMatch(value);

  static bool isNotEmpty(String value) => value.trim().isNotEmpty;
}
