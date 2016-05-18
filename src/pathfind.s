use queue

type move{type xyz}
move.as_text = "#move{[$type] [$xyz]}"

Dir4 = [[0 -1] [1 0] [0 1] [-1 0]]

player.excavate_mark X Y Z =
| W = $world.units_at{X,Y,0}.find{(?type><unit_work and ?owner.id><$id)}
| if got W then W else 0

list_moves Me Src =
| Ms = []
| SX,SY,SZ = Src
| CanMove = $can_move
| for DX,DY Dir4
  | X = SX+DX
  | Y = SY+DY
  | Z = SZ
  | Dst = X,Y,Z
  | if CanMove{Me Src Dst} then
    | when $world.at{X Y Z-1}.empty: Dst.2 <= $world.fix_z{Dst} //gonna fall
    else
    | Tile = $world.at{X Y Z}
    | if Tile.type >< border_ then Dst <= 0
      else | Dst.2 <= $world.fix_z{Dst}
           | less CanMove{Me Src Dst}: Dst <= 0
  | when Dst:
    | B = $world.block_at{Dst} //FIXME: could be optimized
    | if got B then
        | if $owner.id <> B.owner.id
          then if B.alive and $damage and (SZ-Z).abs<<1 then
                 | push move{attack Dst} Ms
               else when B.ai><remove and $worker
                        and $owner.excavate_mark{X Y Z}:
                 | push move{move Dst} Ms
          else when B.speed and B.can_move{}{B Dst Src}:
               | push move{swap Dst} Ms //FIXME: consider moving B back
      else push move{move Dst} Ms
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
| BestXYZ = XYZ
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
      | when BestL>>NewL and (BestL>NewL or TargetXYZ.2><DXYZ.2):
        | BestL <= NewL
        | BestXYZ <= DXYZ
        | R <= [Node Dst]
        | when BestL < 2.0:
          | when BestXYZ><TargetXYZ: _goto end
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
| if R then [R.0 R.1.xyz 0]^node_to_path else 0

unit.pathfind MaxCost Check = $world.pathfind{MaxCost Me $xyz Check}

unit.find MaxCost Check =
| Found = $world.pathfind{MaxCost Me $xyz Check}
| if Found then Found.1 else 0

//FIXME: AI version should setup unit_block
unit.path_to XYZ close/0 =
| Found = $world.pathfind_closest{1000 Me $xyz XYZ}
| if Found then Found else []


export node_to_path