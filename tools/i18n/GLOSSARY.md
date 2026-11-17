# Glosario de traducción / Translation glossary

Las traducciones viven en `tools/i18n/<código>.json` (`pt`, `fr`, `ca`, `zh`) y se convierten en
`scripts/autoload/lang/i18n_<código>.gd` con `python3 tools/i18n_build.py`. El original (español e
inglés) está en `scripts/autoload/i18n.gd`; `tools/i18n/source.json` es una copia que se regenera con
`godot --headless --script tools/i18n_dump.gd`. Lo que falte en un idioma sale en inglés.

Translations live in `tools/i18n/<code>.json` and are turned into `scripts/autoload/lang/i18n_<code>.gd`
with `python3 tools/i18n_build.py`. Anything missing in a language shows in English.

## Nombres que no se traducen / Names that stay as they are
Kroker, Foox, Svinho, Stolk, Silly, Doc, Luna, Magnus, SuperK, Lil Key, D. Lynx, Charo, Mr. Ad,
Evil Ad, Botcher. En chino también se dejan en letras latinas. / In Chinese they also stay in Latin letters.

| es | en | pt | fr | ca | zh |
|---|---|---|---|---|---|
| El Pinche | The Kitchen Boy | o Ajudante | le Commis | el Marmitó | 小帮厨 |
| sueño | dream | sonho | rêve | somni | 梦 |
| Acto | Act | Ato | Acte | Acte | 第…幕 |
| plano astral | astral plane | plano astral | plan astral | pla astral | 星界 |
| don (mejora) | gift | dom | don | do | 恩赐 |
| amistad | friendship | amizade | amitié | amistat | 友谊 |
| trozos de estrella | star shards | fragmentos de estrela | éclats d'étoile | trossos d'estrella | 星星碎片 |
| Realidad Fragmentada | Fragmented Reality | Realidade Fragmentada | Réalité Fragmentée | Realitat Fragmentada | 碎裂现实 |
| pijama | pajama | pijama | pyjama | pijama | 睡衣 |
| agujero | hole | buraco | trou | forat | 洞 |
| oleada | wave | onda | vague | onada | 波 |
| élite | elite | elite | élite | elit | 精英 |
| jefe | boss | chefe | boss | cap | 首领 |
| pesadilla (dificultad) | nightmare | pesadelo | cauchemar | malson | 噩梦 |
| despertar | wake up | acordar | se réveiller | despertar | 醒来 |
| nivel | level | nível | niveau | nivell | 等级 |
| museo | museum | museu | musée | museu | 博物馆 |
| álbum de pegatinas | sticker album | álbum de figurinhas | album d'autocollants | àlbum d'adhesius | 贴纸册 |
| kiosco de Charo | Charo's kiosk | quiosque da Charo | kiosque de Charo | quiosc de la Charo | Charo的小卖部 |
| dúo | duo | dupla | duo | duo | 双人 |

## Palabras clave (se resaltan; ver `scripts/ui/keywords.gd`) / Keywords (highlighted)
Usar exactamente estas formas para que se resalten. / Use exactly these forms so they get highlighted.

| id | pt | fr | ca | zh |
|---|---|---|---|---|
| bleed | sangramento, sangrar | saignement, saigner | sagnat, sagnar | 流血 |
| burn | queimadura, queimar | brûlure, brûler | cremada, cremar | 灼烧 |
| slow | câmera lenta, desacelerar | ralenti, ralentir | càmera lenta, alentir | 慢动作, 减速 |
| freeze | congelar, congelado | congeler, gelé | congelar, congelat | 冻结 |
| glitch | glitch | glitch | glitch | 故障 |
| fluff | fiapos | duvet | borrissol | 绒毛 |
| stuck | grudado(s) | collé(s) | enganxat(s) | 粘住 |
| heavy | golpe forte | coup puissant | cop fort | 重击 |
| knockback | empurrar, empurrão | repousser | empènyer, empenta | 击退 |
| rooted | imobilizado, paralisado | immobilisé, paralysé | immobilitzat, paralitzat | 定身, 麻痹 |
| stench | mau cheiro, fedor | puanteur | pudor | 恶臭 |
| hack | hackear | hacker | hackejar | 入侵 |
| crit | crítico | critique | crític | 暴击 |
| defense | defesa | défense | defensa | 防御 |
| luck | sorte | chance | sort | 幸运 |
| parry | parry | parry | parry | 格挡 |
| attack_speed | velocidade de ataque | vitesse d'attaque | velocitat d'atac | 攻击速度 |
| regen | regeneração | régénération | regeneració | 生命恢复 |
| lifesteal | roubo de vida | vol de vie | robatori de vida | 吸血 |
| reality | Realidade Fragmentada | Réalité Fragmentée | Realitat Fragmentada | 碎裂现实 |
| bully | valentão, indefeso | caïd, sans défense | abusó, indefens | 恃强凌弱, 毫无防备 |
| grudge | revanche, na lista | revanche, sur sa liste | revenja, a la llista | 报复, 记仇 |
| plaster | curativos | pansements | tiretes | 创可贴 |
| rescue | segunda opinião | deuxième avis | segona opinió | 第二意见 |
