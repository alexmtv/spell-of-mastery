// game world update routines


main.update =
| $world.update

world.update =
| $picked <= $picked^uncons{picked}.skip{?removed}^cons{picked}
| $active <= $active^uncons{active}.keep{?update}^cons{active}
| !$cycle + 1

unit.can_move_to XYZ = 1

unit.update =
| when $removed: leave 0
| when $ordered.valid
  | when $ordered.priority >> $next_action.priority
    | swap $ordered $next_action
  | $ordered.class <= 0
| till $action.cycles // action is done?
  | $action.finish
  | less $next_action.valid: $next_action.init{still $xyz}
  | swap $action $next_action
  | $next_action.class <= 0
  | $next_action.priority <= 0
  | $action.start
| $action.update
| 1