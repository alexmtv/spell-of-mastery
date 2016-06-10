use queue util

//note: here order is important, or path will go zig-zag
//Dirs = [[-1 -1] [1 1] [1 -1] [-1 1] [0 -1] [1 0] [0 1] [-1 0]]

unit.list_moves Src =
| Ms = []
| CanMove = $can_move
| for Dst Src.neibs
  | if Dst.tile.type >< border_ then Dst <= 0
    else | Dst <= Dst.fix_z
         | less CanMove{Me Src Dst}: Dst <= 0
  | when Dst:
    | B = Dst.block
    | if B then
        | if $owner.id <> B.owner.id
          then if B.alive and $damage and (Src.z-Dst.z).abs<<1
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
    | for Dst U.list_moves{Src}:
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

world.find MaxCost U StartCell Check =
| Found = $pathfind{MaxCost U StartCell Check}
| if Found then Found.xyz else 0

unit.find MaxCost Check = $world.find{MaxCost Me $cell Check}

unit.pathfind MaxCost Check = $world.pathfind{MaxCost Me $cell Check}

unit.path_to XYZ close/0 =
| Found = $world.closest_reach{1000 Me $cell XYZ}
| if Found then Found.path else []

