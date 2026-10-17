class_name StatModifier
extends Resource

# DAMAGE e MAX_HEALTH em pontos; SPEED e ATTACK_COOLDOWN em fracao (0.2 = +20%)

enum Stat { DAMAGE, MAX_HEALTH, SPEED, ATTACK_COOLDOWN }

@export var stat: Stat
@export var amount := 0.0


func describe() -> String:
	match stat:
		Stat.DAMAGE:
			return "%+d de dano" % roundi(amount)
		Stat.MAX_HEALTH:
			return "%+d de vida máxima" % roundi(amount)
		Stat.SPEED:
			return "%+d%% de velocidade" % roundi(amount * 100.0)
		Stat.ATTACK_COOLDOWN:
			return "%+d%% de tempo entre ataques" % roundi(amount * 100.0)
	return ""
