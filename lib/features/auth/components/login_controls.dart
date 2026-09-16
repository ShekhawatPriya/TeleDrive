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
          placeholder: code ? '000000' : label,
          placeholderStyle: style?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: .6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          prefix: prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    prefix!,
                    style: style?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
          suffix: suffix,
          decoration: BoxDecoration(
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
        if (!busy) ...[
          const SizedBox(width: 12),
          Icon(
            ios ? CupertinoIcons.arrow_right : Icons.arrow_forward_rounded,
            size: 20,
            color: foreground,
          ),
        ],
      ],
    );
    return Semantics(
      liveRegion: busy,
      child: ios
          ? CupertinoButton.filled(
              onPressed: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(19),
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
