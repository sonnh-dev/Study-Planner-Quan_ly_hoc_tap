import 'package:flutter/material.dart';
import 'package:studyplaner/data/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onSignedIn,
    required this.onContinueOffline,
  });
  final ApiClient api;
  final Future<void> Function(String token, String email) onSignedIn;
  final Future<void> Function() onContinueOffline;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(
        _register ? '/auth/register' : '/auth/login',
        {'email': _email.text.trim(), 'password': _password.text},
      );
      final data = response['result'] as Map<String, dynamic>;
      await widget.onSignedIn(data['token'] as String, data['email'] as String);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width > 900 ? 920 : 430),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: width > 900
                ? Row(
                    children: [
                      Expanded(child: _brandPanel()),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(36),
                          child: _form(),
                        ),
                      ),
                    ],
                  )
                : Padding(padding: const EdgeInsets.all(30), child: _form()),
          ),
        ),
      ),
    );
  }

  Widget _brandPanel() => Container(
    height: 520,
    padding: const EdgeInsets.all(44),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF3155C8), Color(0xFF7595F3)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(Icons.auto_awesome, color: Colors.white, size: 42),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Học có kế hoạch.\nTiến bộ mỗi ngày.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                height: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Lịch học, lộ trình và ghi chú của bạn ở cùng một nơi.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        Text(
          'STUDY PLANNER',
          style: TextStyle(color: Colors.white70, letterSpacing: 1.2),
        ),
      ],
    ),
  );

  Widget _form() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        _register
            ? 'Tạo tài khoản để đồng bộ giữa các thiết bị.'
            : 'Đăng nhập để đồng bộ lịch học và ghi chú.',
      ),
      const SizedBox(height: 26),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Mật khẩu (ít nhất 8 ký tự)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.lock_outline),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _busy
                ? 'Đang xử lý…'
                : _register
                ? 'Đăng ký'
                : 'Đăng nhập',
          ),
        ),
      ),
      TextButton(
        onPressed: () => setState(() {
          _register = !_register;
          _error = null;
        }),
        child: Text(
          _register
              ? 'Đã có tài khoản? Đăng nhập'
              : 'Chưa có tài khoản? Đăng ký',
        ),
      ),
      OutlinedButton.icon(
        onPressed: widget.onContinueOffline,
        icon: const Icon(Icons.wifi_off),
        label: const Text('Tiếp tục ở chế độ offline'),
      ),
    ],
  );
}
