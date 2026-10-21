"""Validação de ficheiros LUT 3D .cube (REQ-VID-COL-009).

Regras: cabeçalho LUT_3D_SIZE com grelha 17, 33 ou 65; exatamente N³ linhas de três
valores; todos os valores em [0.0, 1.0] (com DOMAIN_MIN/MAX por omissão).
"""

ALLOWED_SIZES = (17, 33, 65)


class CubeError(ValueError):
    pass


def validate_cube_text(text):
    size = None
    values = 0
    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        head = line.split()[0].upper()
        if head == "TITLE":
            continue
        if head == "LUT_1D_SIZE":
            raise CubeError("LUT 1D não suportado: é necessário um LUT 3D")
        if head == "LUT_3D_SIZE":
            try:
                size = int(line.split()[1])
            except (IndexError, ValueError):
                raise CubeError(f"Linha {lineno}: LUT_3D_SIZE inválido")
            if size not in ALLOWED_SIZES:
                raise CubeError(f"Grelha {size}³ não suportada (use 17, 33 ou 65)")
            continue
        if head in ("DOMAIN_MIN", "DOMAIN_MAX"):
            nums = line.split()[1:]
            expected = ["0", "0", "0"] if head == "DOMAIN_MIN" else ["1", "1", "1"]
            try:
                if [float(n) for n in nums] != [float(e) for e in expected]:
                    raise CubeError(f"Linha {lineno}: {head} diferente de {' '.join(expected)} não suportado")
            except ValueError:
                raise CubeError(f"Linha {lineno}: {head} inválido")
            continue
        parts = line.split()
        if len(parts) != 3:
            raise CubeError(f"Linha {lineno}: esperados três valores")
        if size is None:
            raise CubeError("Cabeçalho LUT_3D_SIZE em falta antes dos dados")
        try:
            nums = [float(p) for p in parts]
        except ValueError:
            raise CubeError(f"Linha {lineno}: valor não numérico")
        if any(n < 0.0 or n > 1.0 for n in nums):
            raise CubeError(f"Linha {lineno}: valores fora de [0,0; 1,0]")
        values += 1
    if size is None:
        raise CubeError("Cabeçalho LUT_3D_SIZE em falta")
    if values != size ** 3:
        raise CubeError(f"Esperadas {size ** 3} entradas para a grelha {size}³, encontradas {values}")
    return size
