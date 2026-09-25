import '../constants/app_constants.dart';

class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu correo';
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value)) return 'Correo inválido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Mínimo ${AppConstants.minPasswordLength} caracteres';
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return 'Máximo ${AppConstants.maxPasswordLength} caracteres';
    }
    return null;
  }

  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'Ingresa $fieldName' : 'Campo requerido';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!regex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
      return 'Teléfono inválido';
    }
    return null;
  }

  static String? capital(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa el capital';
    final amount = double.tryParse(value);
    if (amount == null) return 'Monto inválido';
    if (amount < AppConstants.minCapital) {
      return 'Mínimo \$${AppConstants.minCapital}';
    }
    if (amount > AppConstants.maxCapital) {
      return 'Máximo \$${AppConstants.maxCapital}';
    }
    return null;
  }

  static String? riskPercentage(String? value) {
    if (value == null || value.isEmpty) return 'Selecciona tu riesgo';
    final risk = double.tryParse(value);
    if (risk == null) return 'Valor inválido';
    if (!AppConstants.riskOptions.contains(risk)) {
      return 'Opciones: ${AppConstants.riskOptions.join(", ")}%';
    }
    return null;
  }
}
