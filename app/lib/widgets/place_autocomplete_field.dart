import 'dart:async';
import 'package:flutter/material.dart';
import '../services/places_service.dart';
import '../theme/theme.dart';

/// A text field that shows Mapbox Search Box suggestions as the user types
/// and resolves the chosen one to a label + lat/lng via [onPicked].
/// Debounces keystrokes so it doesn't fire a request per character.
class PlaceAutocompleteField extends StatefulWidget {
  final PlacesService places;
  final String hintText;
  final String initialText;
  final void Function(PlaceDetails place) onPicked;

  const PlaceAutocompleteField({
    super.key,
    required this.places,
    required this.onPicked,
    this.hintText = 'Search for a place',
    this.initialText = '',
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  late final _controller = TextEditingController(text: widget.initialText);
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  bool _picked = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _picked = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      final results = await widget.places.suggest(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() {
      _suggestions = [];
      _loading = true;
    });
    final details = await widget.places.retrieve(s);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _picked = true;
      _controller.text = details?.label ?? s.label;
    });
    widget.places.newSession(); // start a fresh billed session for the next search
    if (details != null) widget.onPicked(details);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          onTap: () {
            if (_picked) widget.places.newSession();
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_picked ? const Icon(Icons.check_circle, color: ConvoyColors.signal, size: 20) : null),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: ConvoyColors.panel2,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ConvoyColors.stroke),
            ),
            child: Column(
              children: _suggestions
                  .map((s) => InkWell(
                        onTap: () => _pick(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                          child: Text(s.label, style: const TextStyle(fontSize: 13.5)),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
