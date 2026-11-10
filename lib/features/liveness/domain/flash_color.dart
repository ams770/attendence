/// Discrete screen illumination colors used during the flash liveness challenge.
enum FlashColor {
  red(r: 255, g: 0, b: 0),
  green(r: 0, g: 255, b: 0),
  blue(r: 0, g: 0, b: 255),
  white(r: 255, g: 255, b: 255);

  const FlashColor({required this.r, required this.g, required this.b});

  final int r;
  final int g;
  final int b;
}
