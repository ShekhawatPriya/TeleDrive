import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single auth-field contract; editing, autofill and selection follow the OS.
class LoginTextField extends StatelessWidget {
  const LoginTextField({
    required this.controller,
    required this.label,
    required this.onSubmitted,
    required this.keyboardType,
    required this.action,
    this.autofillHints,
    this.formatters,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.autofocus = false,
    this.enabled = true,
    this.code = false,
    this.grouped = false,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onSubmitted;
  final TextInputType keyboardType;
  final TextInputAction action;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? formatters;
  final String? prefix;
  final Widget? suffix;
  final bool obscure, autofocus, enabled, code;

  /// iOS: the field is a row inside an inset group that draws the surface.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = code
        ? theme.textTheme.headlineMedium?.copyWith(
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
          )
        : theme.textTheme.bodyLarge?.copyWith(fontSize: 17);
    if (theme.platform == TargetPlatform.iOS) {
      return Semantics(
        label: label,
        child: CupertinoTextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: action,
          autofillHints: autofillHints,
          inputFormatters: formatters,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          onSubmitted: onSubmitted,
          style: style,
          // Telegram chooses the code length, so the placeholder names the
          // field instead of implying a digit count.
          placeholder: code ? 'Code' : label,
          placeholderStyle: style?.copyWith(
            letterSpacing: code ? 0 : null,
            color: scheme.onSurfaceVariant.withValues(alpha: .6),
          ),
          padding: grouped
              ? EdgeInsets.fromLTRB(prefix == null ? 16 : 12, 16, 16, 16)
              : const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          textAlign: code && grouped ? TextAlign.center : TextAlign.start,
          prefix: prefix == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(left: grouped ? 16 : 18),
                  child: Text(
                    prefix!,
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
          suffix: suffix,
          decoration: grouped
              ? null
              : BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
        ),
      );
    }
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: action,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      obscureText: obscure,
      enableSuggestions: false,
      autocorrect: false,
      onSubmitted: onSubmitted,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        hintText: code ? '000000' : null,
        prefixText: prefix == null ? null : '$prefix ',
        prefixStyle: style,
        suffixIcon: suffix,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
      ),
    );
  }
}

class LoginPrimaryButton extends StatelessWidget {
  const LoginPrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final foreground = busy
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimary;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 20,
            height: 20,
            child: ios
                ? CupertinoActivityIndicator(color: foreground)
                : CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
        if (busy) const SizedBox(width: 12),
        Flexible(
          child: Text(
            busy ? 'Connecting…' : label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // iOS buttons carry a plain label; Android keeps its arrow.
        if (!busy && !ios) ...[
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward_rounded, size: 20, color: foreground),
        ],
      ],
    );
    return Semantics(
      liveRegion: busy,
      child: ios
          ? CupertinoButton.filled(
              onPressed: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(100),
              padding: const EdgeInsets.all(17),
              child: content,
            )
          : FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(19),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: content,
            ),
    );
  }
}
