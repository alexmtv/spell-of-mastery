use stack gui

player.active =
| PID = $id
| Turn = $world.turn
| $world.active.list.keep{(?owner.id >< PID and ?moved <> Turn)}

Map = dup 32: dup 32: 0

type mark{type xyz}


unit.can_move Src Dst =
| less $world.at{Dst}.empty: leave 0
| [SX SY SZ] = Src
| [DX DY DZ] = Dst
| Height = DZ-SZ
| HeightAbs = Height.abs
| when HeightAbs << $jumps: leave 1
| BelowDst = DX,DY,DZ-1
| BelowDstTile = $world.at{BelowDst}
| when BelowDstTile.stairs: leave HeightAbs << (max 4 $jumps)
| BelowSrc = SX,SY,SZ-1
| SlopedSrc = $world.slope_at{BelowSrc}<>#@1111
| BelowSrcTile = $world.at{BelowSrc}
| when BelowSrcTile.stairs and Height<0: leave HeightAbs << (max 4 $jumps)
| 0

Dirs2d = [[0 -1] [1 0] [0 1] [-1 0]]

unit.moves_list @As =
| less $moves.size: leave []
| XYZ = if As.size then As.0 else $xyz
| Marks = []
| I = 0
| Ms = $moves.deep_copy
| O = Ms.size/2
| advance XY =
  | Ns = Dirs2d{?+XY}.keep{Ms.?0.?1}
  | for X,Y Ns: Ms.X.Y <= 0
  | Ns{[XY ?]}
| Stack = advance [O O]
| till Stack.end
  | [SX,SY DX,DY] = pop Stack
  | Src = XYZ + [SX-O SY-O 0]
  | Dst = XYZ + [DX-O DY-O 0]
  | Mark = 0
  | Blocked = Dst.0 < 0 or Dst.1 < 0
  | less Blocked
    | !Dst.2 - 1
    | while $world.at{Dst}.empty: !Dst.2 - 1
    | !Dst.2 + 1
    | less $can_move{Src Dst}
      | AboveDst = Dst + [0 0 $world.at{Dst}.height]
      | when $can_move{Src AboveDst}: Dst <= AboveDst
    | less $world.no_block_at{Dst} and $can_move{Src Dst}:
      | when got!it $world.block_at{Dst}:
        | when $can_move{Src Dst}
          | if  $owner.id >< it.owner.id
            then | when and it.moves.size
                        and it.can_move{Dst Src}:
                   | Mark <= mark swap Dst
            else when it.hits < it.health and it.defense < $attack:
                 | Mark <= mark attack Dst
      | Blocked <= 1
  | less Blocked
    | Mark <= mark move Dst
    | for N (advance [DX DY]): push N Stack
  | when Mark: push Mark Marks
| Marks.list

unit.mark_moves @As =
| less $moves.size: leave []
| XYZ = if As.size then As.0 else $xyz
| Marks = []
| I = 0
| Ms = $moves.deep_copy
| O = Ms.size/2
| advance Prev XY =
  | Ns = Dirs2d{?+XY}.keep{Ms.?0.?1}
  | for X,Y Ns: Ms.X.Y <= 0
  | Ns{[Prev XY ?]}
| Stack = advance 0 [O O]
| till Stack.end
  | [Prev SX,SY DX,DY] = pop Stack
  | Src = XYZ + [SX-O SY-O 0]
  | Dst = XYZ + [DX-O DY-O 0]
  | Mark = 0
  | Blocked = Dst.0 < 0 or Dst.1 < 0
  | less Blocked
    | !Dst.2 - 1
    | while $world.at{Dst}.empty: !Dst.2 - 1
    | !Dst.2 + 1
    | less $can_move{Src Dst}
      | AboveDst = Dst + [0 0 $world.at{Dst}.height]
      | when $can_move{Src AboveDst}: Dst <= AboveDst
    | less $world.no_block_at{Dst} and $can_move{Src Dst}:
      | when got!it $world.block_at{Dst}:
        | when $can_move{Src Dst}
          | if  $owner.id >< it.owner.id
            then | when and it.moves.size
                        and it.can_move{Dst Src}:
                   | Mark <= $world.alloc_unit{mark_swap}
            else when it.hits < it.health and it.defense < $attack:
                 | Mark <= $world.alloc_unit{mark_attack}
      | Blocked <= 1
  | less Blocked
    | Mark <= $world.alloc_unit{mark_move}
    | for N (advance Mark [DX DY]): push N Stack
  | when Mark
    | Mark.move{Dst}
    | Mark.path <= Prev
    | push Mark Marks
| Marks.list

ai.update =
| Turn = $world.turn
| Units = $player.active
| Moved = $player.moves << 0
| maked_order U Mark =
  | $player.picked.moved <= $world.turn
  | $world.update_pick{[U]}
  | U.guess_order_at_mark{Mark}
  | Moved <= 1
| less Moved: for U Units: 
  | Ms = U.mark_moves
  | As = Ms.keep{?type >< mark_attack}
  | case As [A@_]:
    | maked_order U A
  | for M Ms: M.free
  | when Moved: leave
| for U Units:
  | UID = U.id
  | X,Y,Z = U.xyz
  | for Xs Map: for I Xs.size: Xs.I <= #100000
  | Map.X.Y <= 0
  | Targets = []
  | Stack = [[0 U.xyz 0]]
  | Count = 0
  | StartTime = get_gui{}.ticks{}
  | till Stack.end
    | Node = pop Stack
    | [Prev XYZ Cost] = Node
    | X,Y,Z = XYZ
    | NextCost = Cost+1
    | for M U.moves_list{XYZ}:
      | !Count+1
      | when M.type >< attack:
        | case $world.units_at{M.xyz}.skip{?empty} [T@_]:
          | less Targets.any{?id >< T.id}: push T Targets
      | case M.xyz X,Y,Z: when NextCost < Map.X.Y:
        | Map.X.Y <= NextCost
        | push [Node M.xyz NextCost] Stack
  | EndTime = get_gui{}.ticks{}
  | say [Count EndTime-StartTime]
  | when Targets.size
    | Target = Targets{[Map.(?xyz.0).(?xyz.1) ?]}.sort{?0 < ??0}.0.1
    | Path = []
    | XYZ = Target.xyz
    | while 1
      | Ms = U.mark_moves{XYZ}
      | for M Ms: case M.xyz X,Y,Z: when Map.X.Y >< 1:
        | for M Ms: M.free
        | Ms = U.mark_moves
        | XYZ = X,Y,Z
        | case Ms.keep{?xyz >< XYZ} [M@_]: maked_order U M
        | for M Ms: M.free
        | less Moved:
          | bad "ai.update got pathfinding error"
        | leave
      | XYZ <= Ms{[Map.(?xyz.0).(?xyz.1) ?xyz]}.sort{?0 < ??0}.0.1.copy
      | for M Ms: M.free
/*| less Moved: for U Units:
  | Ms = U.mark_moves
  | case Ms [M@_]:
    | maked_order U M
  | for M Ms: M.free
  | when Moved: leave*/
| $world.update_pick{[]}
| $world.end_turn


export