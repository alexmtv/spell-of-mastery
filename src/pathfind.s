use queue util

//note: here order is important, or path will go zig-zag
//Dirs = [[-1 -1] [1 1] [1 -1] [-1 1] [0 -1] [1 0] [0 1] [-1 0]]

unit.list_moves Src =
| Ms = []
| SX,SY,SZ = Src
| CanMove = $can_move
| for Cell $world.cell{SX SY SZ}.neibs
  | Dst = 0
  | less Cell.tile.type >< border_:
    | Cell <= Cell.fix_z
    | Dst <= Cell.xyz
    | less CanMove{Me Src Dst}: Dst <= 0
  | when Dst:
    | B = Cell.block
    | if B then
        | if $owner.id <> B.owner.id
          then if B.alive and $damage and (SZ-Dst.2).abs<<1
               then push Dst Ms //attack
               else
          else when B.speed and B.can_move{}{B Dst Src}:
               | push Dst Ms //FIXME: consider moving B back
      else push Dst Ms
| Ms

PFQueue = queue 256*256

world.pathfind MaxCost U StartCell Check =
| less U.speed: leave 0
| X,Y,Z = StartCell.xyz
| StartCost = $new_visit
| !MaxCost+StartCost
| StartCell.visited <= StartCost
| StartCell.prev <= 0
| PFQueue.reset
| PFQueue.push{StartCell}
| R = 0
//| StartTime = clock
| till PFQueue.end
  | Src = PFQueue.pop
  | Cost = Src.visited
  | when Cost<MaxCost:
    | NextCost = Cost+1
    | for DXYZ U.list_moves{Src.xyz}:
      | Dst = $cell{DXYZ.0 DXYZ.1 DXYZ.2}
      | when NextCost < Dst.visited:
        | Dst.prev <= Src
        | C = Check Dst
        | when C:
          | if C><block then NextCost <= Dst.visited
            else | Dst.prev <= Src
                 | R <= Dst
                 | _goto end
        | Dst.visited <= NextCost
        | PFQueue.push{Dst}
| _label end
//| EndTime = clock
//| say EndTime-StartTime
| R

world.closest_reach MaxCost U StartCell TargetXYZ =
| less U.speed: leave 0
| X,Y,Z = StartCell.xyz
| TX,TY,TZ = TargetXYZ
| TCell = $cell{@TargetXYZ}
| BestL = [TX-X TY-Y].abs
| Best = 0
| check Dst =
  | R = 0
  | DX,DY,DZ = Dst.xyz
  | NewL = [TX-DX TY-DY].abs
  | when BestL>>NewL and (BestL>NewL or TZ><DZ):
    | BestL <= NewL
    | Best <= Dst
    | when BestL < 2.0:
      | when Best><TCell: | R <= 1; _goto end
      | less TCell.tile.empty: | R <= 1; _goto end
      | B = TCell.block
      | when B:
        | less B.speed: | R <= 1; _goto end
        | when not U.damage and U.owner.is_enemy{B.owner}: | R <= 1; _goto end
  | _label end
  | R
| $pathfind{MaxCost U StartCell &check}
| Best

/*world.closest_reach MaxCost U StartCell TargetXYZ =
| less U.speed: leave 0
| X,Y,Z = StartCell.xyz
| TargetXY = TargetXYZ.take{2}
| BestXYZ = X,Y,Z
| BestL = (TargetXY-[X Y]).abs
| StartCost = $new_visit
| !MaxCost+StartCost
| StartCell.visited <= StartCost
| StartCell.prev <= 0
| PFQueue.reset
| PFQueue.push{StartCell}
| R = 0
| till PFQueue.end
  | Src = PFQueue.pop
  | Cost = Src.visited
  | when Cost<MaxCost:
    | NextCost = Cost+1
    | for DXYZ U.list_moves{Src.xyz}:
      | X,Y,Z = DXYZ
      | Dst = $cell{X Y Z}
      | when NextCost < Dst.visited:
        | NewL = (TargetXY-[X Y]).abs
        | when BestL>>NewL and (BestL>NewL or TargetXYZ.2><DXYZ.2):
          | BestL <= NewL
          | BestXYZ <= DXYZ
          | Dst.prev <= Src
          | R <= Dst
          | when BestL < 2.0:
            | when BestXYZ><TargetXYZ: _goto end
            | less $at{@TargetXYZ}.empty: _goto end
            | B = $block_at{TargetXYZ}
            | when B:
              | less B.speed: _goto end
              | when not U.damage and U.owner.is_enemy{B.owner}: _goto end
        | Dst.visited <= NextCost
        | Dst.prev <= Src
        | PFQueue.push{Dst}
| _label end
| R*/

world.find MaxCost U StartCell Check =
| Found = $pathfind{MaxCost U StartCell Check}
| if Found then Found.xyz else 0

unit.find MaxCost Check = $world.find{MaxCost Me $cell Check}

unit.pathfind MaxCost Check = $world.pathfind{MaxCost Me $cell Check}

unit.path_to XYZ close/0 =
| Found = $world.closest_reach{1000 Me $cell XYZ}
| if Found then Found.path else []

