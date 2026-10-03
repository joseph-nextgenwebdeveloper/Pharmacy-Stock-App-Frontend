class RouteNames {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const inventory = '/inventory';
  static const addMedicine = '/inventory/add';
  static const batches = '/inventory/batches';
  static const medicine = '/medicine';
  static const purchases = '/purchases';
  static const sales = '/sales';
  static const suppliers = '/suppliers';
  static const reports = '/reports';
  static const scanner = '/scanner';
  static const alerts = '/alerts';
  static const profile = '/profile';
  static const movementHistory = '/movement-history';
  static const more = '/more';
  static String medicineDetail(int id) {
    return '$medicine/$id';
  }
}