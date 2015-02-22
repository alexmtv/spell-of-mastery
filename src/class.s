use gfx util param

type class{bank class_name static/0 empty/0 sprite/system_dummy
           unit/0 draw_order/10 aux/0 shadow/0 moves/0 speed/1
           starts/0 jumps/1 mountaineer/0 ranger/0 health/0
           level/0}
  type/"[Bank]_[Class_name]"
  static/Static
  empty/Empty
  default_sprite/Sprite
  unit/Unit
  draw_order/Draw_order
  aux/Aux
  shadow/Shadow // unit casts shadow in air
  moves/Moves // moves per turn
  speed/Speed // how many cycles it takes to move between cells
  starts/Starts // non-zero if unit starts active
  jumps/Jumps
  ranger/Ranger
  mountaineer/Mountaineer
  health/Health
  level/Level

class.height = $default_sprite.height

main.load_classes =
| BankNames = case $params.world.class_banks [@Xs](Xs) X[X]
| $classes <= @table: @join: map BankName BankNames
  | map Name,Params $params.BankName
    | R = class BankName Name @Params.list.join
    | S = $sprites.(R.default_sprite)
    | less got S: bad "missing sprite `[R.default_sprite]`"
    | R.default_sprite <= S
    | "[BankName]_[Name]",R
| for S $sprites{}{?1}.keep{?class}
  | C = class S.bank S.name @S.class
  | C.default_sprite <= S
  | $classes."[S.bank]_[S.name]" <= C

export class
