use queue

type move{type xyz}
move.as_text = "#move{[$type] [$xyz]}"

Dir4 = [[0 -1] [1 0] [0 1] [-1 0]]

list_moves Me Src =
| Ms = []
| SX,SY,SZ = Src
| Digger = $digger
| for DX,DY Dir4
  | X = SX+DX
  | Y = SY+DY
  | Z = SZ
  | Tile = $world.at{X Y Z}
  | if Tile.type >< border_ then
    else if Digger and Tile.clear and (Z-$world.fix_z{X,Y,Z}).abs>4 then
     | push move{excavate [X Y Z]} Ms
    else
    | when Digger
      | $world.at{X Y Z}
    | Z <= $world.fix_z{X,Y,Z}
    | Dst = [X Y Z]
    | B = $world.block_at{Dst}
    | if got B then
        | if $owner.id <> B.owner.id
          then when B.alive and $damage and (SZ-Z).abs<<4:
               | push move{attack Dst} Ms
          else when B.speed and $can_move{}{Me Src Dst} and B.can_move{}{B Dst Src}:
               | push move{swap Dst} Ms //when B cant move to Src, ask B to move back
      else when $can_move{}{Me Src Dst}: push move{move Dst} Ms
| Ms


node_to_path Node =
| Path = []
| while Node
  | Prev,XYZ,Cost = Node
  | push XYZ Path
  | Node <= Prev
| Path.tail.list

PFMap = dup 134: dup 134: dup 64: #FFFFFFFFFFFF
PFQueue = queue 256*256
PFCount = #FFFFFF

pf_reset_count =
| for Ys PFMap: for Xs Ys: Xs.init{#FFFFFFFFFFFF}
| PFCount <= #FFFFFF

world.pathfind MaxCost U XYZ Check =
| less U.speed: leave 0
| X,Y,Z = XYZ
| !PFCount-1
| less PFCount: pf_reset_count
| StartCost = PFCount*#1000000
| !MaxCost+StartCost
| PFMap.X.Y.Z <= StartCost
| PFQueue.push{[0 XYZ StartCost]}
| R = 0
//| StartTime = clock
| till PFQueue.end
  | Node = PFQueue.pop
  | Prev,XYZ,Cost = Node
  | when Cost<MaxCost:
    | X,Y,Z = XYZ
    | NextCost = Cost+1
    | for Dst list_moves{U XYZ}:
      | when Check Dst:
        | R <= [Node Dst.xyz $block_at{Dst.xyz}]
        | _goto end
      | X,Y,Z = Dst.xyz
      | MXY = PFMap.X.Y
      | when NextCost < MXY.Z and Dst.type:
        | MXY.Z <= NextCost
        | PFQueue.push{[Node Dst.xyz NextCost]}
| _label end
//| EndTime = clock
//| say EndTime-StartTime
| PFQueue.clear
| R

world.pathfind_closest MaxCost U XYZ TargetXYZ =
| less U.speed: leave 0
| X,Y,Z = XYZ
| !PFCount-1
| less PFCount: pf_reset_count
| StartCost = PFCount*#1000000
| !MaxCost+StartCost
| PFMap.X.Y.Z <= StartCost
| PFQueue.push{[0 XYZ StartCost]}
| BestXYZ = U.xyz
| TargetXY = TargetXYZ.take{2}
| BestL = (TargetXY-BestXYZ.take{2}).abs
| R = 0
| till PFQueue.end
  | Node = PFQueue.pop
  | Prev,XYZ,Cost = Node
  | when Cost<MaxCost:
    | X,Y,Z = XYZ
    | NextCost = Cost+1
    | for Dst list_moves{U XYZ}:
      | DXYZ = Dst.xyz
      | NewL = (TargetXY-DXYZ.take{2}).abs
      | when BestL>NewL:
        | BestL <= NewL
        | R <= [Node Dst]
        | when BestL < 2.0:
          | when BestL < 1.0: _goto end
          | less $at{@TargetXYZ}.empty: _goto end
          | B = $block_at{TargetXYZ}
          | when got B:
            | less B.speed: _goto end
            | when not U.damage and U.owner.is_enemy{B.owner}: _goto end
      | X,Y,Z = Dst.xyz
      | MXY = PFMap.X.Y
      | when NextCost < MXY.Z
        | MXY.Z <= NextCost
        | PFQueue.push{[Node Dst.xyz NextCost]}
| _label end
| PFQueue.clear
| if R then [R.0 R.1.xyz 0] else 0

unit.pathfind MaxCost Check = $world.pathfind{MaxCost Me $xyz Check}

//FIXME: AI version should setup unit_block
unit.path_to XYZ close/0 =
| Found = $world.pathfind_closest{1000 Me $xyz XYZ}
| if Found then Found^node_to_path else []


export node_to_path