"""Simulación Monte Carlo de las fórmulas propuestas en docs/design/sistemas/."""
import random
import statistics as st

N = 20000
PARTES = {
    # id: (fraccion_integridad, mod_acierto, mult_cuerpo, amputable)
    "cabeza": (0.25, -25, 2.0, False),
    "torso": (0.50, 10, 1.0, False),
    "brazo": (0.30, -10, 0.6, True),
    "pierna": (0.35, 0, 0.6, True),
}


def ataque(fue, des, agi_obj, poder, precision, armadura, parte):
    frac, mod, mult, _ = PARTES[parte]
    acierto = max(5, min(95, precision + 2 * des - 2 * agi_obj + mod))
    if random.uniform(0, 100) >= acierto:
        return None
    base = poder * (1 + fue / 20) * random.uniform(0.9, 1.1)
    critico = random.uniform(0, 100) < des / 2
    if critico:
        base *= 1.5
    dp = max(1, round(base) - armadura)
    return dp, round(dp * mult), critico


def simular(parte, objetivo, fue=8, des=8, agi=8, res=8, poder=12, precision=75,
            armadura=2, cuerpo_max=100, cortante=True):
    """Devuelve nº de ataques hasta alcanzar 'objetivo' (rota|amputada|caido)."""
    frac, _, _, amputable = PARTES[parte]
    integ_max = cuerpo_max * frac
    integ, cuerpo, estado = integ_max, cuerpo_max, "sana"
    actual = parte
    for n in range(1, 200):
        r = ataque(fue, des, agi, poder, precision, armadura, actual)
        if r is None:
            continue
        dp, dc, crit = r
        cuerpo -= dc
        if actual == parte and estado != "amputada":
            ya_rota = estado == "rota"
            integ -= dp
            if integ <= 0:
                exceso = -integ
                estado = "rota"
                amputa = cortante and amputable and (
                    (ya_rota and dp >= 0.25 * integ_max)
                    or (not ya_rota and exceso >= 0.25 * integ_max)
                    or (crit and not ya_rota)
                )
                if amputa and random.uniform(0, 100) >= min(40, res * 2):
                    estado = "amputada"
                    actual = "torso"  # redirección
                integ = 0
        if objetivo == "rota" and estado in ("rota", "amputada"):
            return n
        if objetivo == "amputada" and estado == "amputada":
            return n
        if objetivo == "caido" and cuerpo <= 0:
            return n
    return 200


def resumen(vals):
    vals = sorted(vals)
    return f"media {st.mean(vals):5.1f} | p10 {vals[len(vals)//10]:3d} | p90 {vals[9*len(vals)//10]:3d}"


print("Atacante FUE 8 DES 8, arma poder 12 prec 75 cortante; objetivo AGI 8 RES 8 armadura 2, Cuerpo 100\n")
for parte in PARTES:
    print(f"[{parte}]")
    print("  romper   :", resumen([simular(parte, "rota") for _ in range(N)]))
    if PARTES[parte][3]:
        print("  amputar  :", resumen([simular(parte, "amputada") for _ in range(N)]))
    print("  derribar :", resumen([simular(parte, "caido") for _ in range(N)]))
print("\nContundente (sin amputación), derribar apuntando a brazo:",
      resumen([simular("brazo", "caido", cortante=False) for _ in range(N)]))
print("Enemigo fuerte (Cuerpo 180, armadura 4) derribar por torso:",
      resumen([simular("torso", "caido", cuerpo_max=180, armadura=4) for _ in range(N)]))
