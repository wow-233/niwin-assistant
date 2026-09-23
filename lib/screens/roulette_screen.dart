import 'dart:math' as math;

import 'package:flutter/material.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  static const _presets = <String, List<String>>{
    '吃什么': ['食堂', '盖饭', '面', '米粉', '轻食', '饺子'],
    '不吃食堂': ['外卖', '面馆', '便利店', '汉堡', '麻辣烫', '不吃了'],
    '外卖': ['炸鸡', '汉堡', '炒饭', '面', '麻辣烫', '随机满减'],
  };

  late final AnimationController _controller;
  final _custom = TextEditingController();
  String _preset = '吃什么';
  late List<String> _options;
  double _rotation = 0;
  String? _result;

  @override
  void initState() {
    super.initState();
    _options = List.of(_presets[_preset]!);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择困难转盘')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          SegmentedButton<String>(
            segments: _presets.keys
                .map((value) => ButtonSegment(value: value, label: Text(value)))
                .toList(),
            selected: {_preset},
            onSelectionChanged: (value) {
              setState(() {
                _preset = value.first;
                _options = List.of(_presets[_preset]!);
                _result = null;
              });
            },
          ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 310,
              height: 330,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Positioned(
                    top: 30,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => Transform.rotate(
                        angle: _rotation * _controller.value,
                        child: child,
                      ),
                      child: CustomPaint(
                        size: const Size.square(280),
                        painter: _WheelPainter(
                          options: _options,
                          scheme: Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 142,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        fixedSize: const Size.square(72),
                      ),
                      onPressed: _controller.isAnimating ? null : _spin,
                      child: const Text('转', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _result == null
                ? const SizedBox(height: 64)
                : Card(
                    key: ValueKey(_result),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: Text(
                          _result!,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text('转盘选项', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _options)
                InputChip(
                  label: Text(option),
                  onDeleted: _options.length <= 2
                      ? null
                      : () => setState(() => _options.remove(option)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  decoration: const InputDecoration(
                    labelText: '添加自定义选项',
                    hintText: '输入后点添加',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(onPressed: _add, child: const Text('添加')),
            ],
          ),
        ],
      ),
    );
  }

  void _add() {
    final value = _custom.text.trim();
    if (value.isEmpty || _options.contains(value)) return;
    setState(() {
      _options.add(value);
      _custom.clear();
    });
  }

  Future<void> _spin() async {
    final random = math.Random();
    final target = random.nextInt(_options.length);
    final slice = math.pi * 2 / _options.length;
    _rotation = math.pi * 10 + (math.pi * 2 - target * slice - slice / 2);
    _controller.reset();
    await _controller.animateTo(1, curve: Curves.easeOutCubic);
    if (!mounted) return;
    setState(() => _result = _options[target]);
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.options, required this.scheme});

  final List<String> options;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final slice = math.pi * 2 / options.length;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var index = 0; index < options.length; index++) {
      final color = index.isEven
          ? scheme.primaryContainer
          : scheme.tertiaryContainer;
      canvas.drawArc(
        rect,
        -math.pi / 2 + index * slice,
        slice,
        true,
        Paint()..color = color,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-math.pi / 2 + (index + .5) * slice);
      final painter = TextPainter(
        text: TextSpan(
          text: options[index],
          style: TextStyle(
            color: index.isEven
                ? scheme.onPrimaryContainer
                : scheme.onTertiaryContainer,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * .62);
      painter.paint(canvas, Offset(radius * .28, -painter.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = scheme.surface,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => true;
}
