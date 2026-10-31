String formatarData(DateTime data) {
  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

  return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year} '
      '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
}
