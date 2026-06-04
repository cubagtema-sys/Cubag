import os
import re

react_pages_dir = r"c:\Users\DELL\Desktop\FLUTTER\CUSTOMS\cubag-react\src\pages"
flutter_pages_dir = r"c:\Users\DELL\Desktop\FLUTTER\CUSTOMS\cubag_flutter\lib\pages"
router_file_path = r"c:\Users\DELL\Desktop\FLUTTER\CUSTOMS\cubag_flutter\lib\core\router.dart"

def to_snake_case(name):
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

def to_kebab_case(name):
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1-\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1-\2', s1).lower()

if not os.path.exists(flutter_pages_dir):
    os.makedirs(flutter_pages_dir)

# Identify pages that shouldn't use AppLayout (auth pages)
auth_pages = ['Login', 'Register', 'ForgotPassword', 'ResetPassword', 'VerifyEmail', 'OTPVerification', 'Landing']

jsx_files = [f for f in os.listdir(react_pages_dir) if f.endswith('.jsx')]

dart_imports = [
    "import 'package:go_router/go_router.dart';",
    "import 'package:shared_preferences/shared_preferences.dart';"
]
routes = []

for jsx_file in jsx_files:
    page_name = jsx_file[:-4] # e.g., 'AdminDashboard'
    if page_name in ['Login', 'Landing', 'Dashboard']: 
        # Skip files we already manually created
        snake_name = to_snake_case(page_name) + '_page'
        dart_imports.append(f"import '../pages/{snake_name}.dart';")
        continue

    snake_name = to_snake_case(page_name) + '_page'
    kebab_name = to_kebab_case(page_name)
    dart_file_name = snake_name + '.dart'
    dart_file_path = os.path.join(flutter_pages_dir, dart_file_name)
    
    # Format route path
    route_path = f"/{kebab_name.replace('admin-', 'admin/')}"
    
    dart_imports.append(f"import '../pages/{dart_file_name}';")
    routes.append(f"    GoRoute(path: '{route_path}', builder: (context, state) => const {page_name}Page()),")

    if page_name in auth_pages:
        # No AppLayout
        dart_content = f"""import 'package:flutter/material.dart';

class {page_name}Page extends StatelessWidget {{
  const {page_name}Page({{super.key}});

  @override
  Widget build(BuildContext context) {{
    return Scaffold(
      appBar: AppBar(title: const Text('{page_name}')),
      body: const Center(
        child: Text('{page_name} UI to be ported from React'),
      ),
    );
  }}
}}
"""
    else:
        # Use AppLayout
        dart_content = f"""import 'package:flutter/material.dart';
import '../components/app_layout.dart';

class {page_name}Page extends StatelessWidget {{
  const {page_name}Page({{super.key}});

  @override
  Widget build(BuildContext context) {{
    return AppLayout(
      title: '{page_name}',
      child: const Center(
        child: Text('{page_name} UI to be ported from React'),
      ),
    );
  }}
}}
"""
    with open(dart_file_path, 'w') as f:
        f.write(dart_content)

print(f"Generated {len(jsx_files)} page files.")

# Generate router.dart
router_content = "\n".join(dart_imports) + """

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getString('cubag_token') != null;
    
    final bool isPublicRoute = state.matchedLocation == '/' || 
                               state.matchedLocation == '/login' || 
                               state.matchedLocation == '/register';

    if (!loggedIn && !isPublicRoute) {
      return '/login';
    }
    
    if (loggedIn && (state.matchedLocation == '/' || state.matchedLocation == '/login')) {
      final role = prefs.getString('cubag_role');
      if (role == 'admin') {
        return '/admin/dashboard';
      }
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LandingPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
""" + "\n".join(routes) + """
  ],
);
"""

with open(router_file_path, 'w') as f:
    f.write(router_content)

print("Updated router.dart")
