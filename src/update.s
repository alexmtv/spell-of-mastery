// game world update routines

main.update =
| $world.update


alloc_ai_blockers Me =
| for U $units: less U.removed: when U.ai >< avoid:
  | B = $alloc_unit{unit_block owner/U.owner}
  | B.move{U.xyz}

free_ai_blockers Me =
| for U $units: less U.removed: when U.type >< unit_block:
  | U.free

world.new_game =
| for K,V $main.params.world: $params.K <= V
| for ActName,Act $main.params.acts: Act.enabled <= #FFFFFF
| $player <= $players.($players.size-1)
| $turn <= 0
| $end_turn // hack to begin turns from 1
| if $params.explored then $explore{1} else $explore{0}
| ActNames = $main.params.acts{}{?0}
| StartMana = $main.params.world.start_mana
| for P $players:
  | P.lore <= 10
  | P.mana <= StartMana
  | Us = P.units
  | less P.human: when Us.size:
    | for ActName ActNames: P.research_item{ActName}
| $human <= $players.1
| when got!it $players.find{?human}: $human <= it

EndTurnDepth = 0

update_spell_of_mastery Me P =
| SOM = P.params.spell_of_mastery
| when got SOM:
  | !SOM-1
  | less SOM > 0:
    | $params.winner <= P.id
    | $params.victory_type <= 'Victory by casting the Spell of Mastery'
    | leave
  | P.params.spell_of_mastery <= SOM
| when P.human: for Q $players:
  | S = Q.params.spell_of_mastery
  | when got S: P.notify{"[Q.name] will finish Spell of Mastery in [S] turns"}

world.end_turn =
| P = $player
| less P.human: free_ai_blockers Me
| Turn = $turn
| for U P.units: 
  | when U.health>0: for V $units_at{U.xyz}: less V.effects.end:
    | V.run_effects{?><tenant_endturn U U.xyz}
  | less U.effects.end:
    | U.run_effects{(X=>case X [`.`endturn N] Turn%N><0) U U.xyz}
    | Remove = []
    | RunEs = []
    | for E U.effects: case E [When Name Duration Params]: when Duration>0:
      | !Duration-1
      | less Duration > 0:
        | when When >< timeout: push Name RunEs
        | push Name Remove
      | E.2 <= Duration
    | for Name Remove: U.strip_effect{Name}
    | for Name RunEs:
      | Effect = $main.params.effect.Name
      | U.effect{Effect U U.xyz}
| PResearch = P.research
| for Type,Act $main.params.acts: when PResearch.Type > Act.research:
  | !PResearch.Type-1 //cooldown
| P.params.view.init{$view.center}
| P.params.cursor.init{$view.cursor}
| NextPlayer = P.id+1
| less NextPlayer < $players.size
  | NextPlayer <= 0
  | !$turn + 1
| P = $players.NextPlayer
| $player <= P
| less P.human: alloc_ai_blockers Me
| update_spell_of_mastery Me P
| when P.human
  | $view.center_at{$player.params.view}
  | $view.cursor.init{$player.params.cursor}
| PID = P.id
| Units = $player.active
| less Units.size /*or $player.human*/:
  | when EndTurnDepth>16
    | EndTurnDepth<=0
    | leave
  | !EndTurnDepth+1
  | $end_turn
  | EndTurnDepth <= 0
  | leave
| P.recalc
| less $turn><1: !P.mana+$player.income
| Leader = P.leader
| when P.mana < $params.defeat_threshold and Leader and Units.size:
  | $main.show_message{'Wizard has Lost Too Much Mana'
       "[P.name] is too exhausted and cannot continue his life."}
  | Leader.harm{Leader 1000}
  | Leader.harm{Leader 1000} //in case leade has shell
  | $effect{Leader.xyz electrical}
| when $turn><1 and P.leader and P.human: $view.center_at{P.leader.xyz cursor/1}
| $on_player_change P
| Turn=$turn
| for U Units:
  | less U.effects.end: U.run_effects{(X=>case X [`.`newturn N] Turn%N><0) U U.xyz}


EventActions = []

check_event_condition Me When =
| case When
  [N<eq+atleast Var Value]
    | V = case Var
        [`.` Player Var]
          | P = $players.Player
          | if Var >< mana then P.mana else P.params.Var
        Else | $params.Var
    | if got V then if N><eq then V >< Value else V >> Value
      else 0
  [always] | 1
  [turn N] | N><$turn
  [got_unit Player UnitType]
    | Units = $players.Player.units
    | got Units.find{?type><UnitType}
  [researched Player ActName]
    | Act = $main.params.acts.ActName
    | less got ActName: "World events references unknown act [ActName]"
    | ResearchSpent = $players.Player.research.(Act.name)
    | ResearchRemain = Act.research - ResearchSpent
    | ResearchRemain << 0
  [`not` X] | not: check_event_condition Me X
  [`and` A B] | check_event_condition Me A and check_event_condition Me B
  [`or` A B] | check_event_condition Me A or check_event_condition Me B
  Else | bad "unexpected event condition [When]"

world.process_events =
| DisabledEvents = have $params.disabled_events []
| for [Id [When @Actions]] $events: when no DisabledEvents.find{Id}:
  | Repeat = 0
  | case When [repeat @RealWhen]
    | When <= RealWhen
    | Repeat <= 1
  | True = check_event_condition Me When
  | less True: Repeat <= 1
  | less Repeat: push Id $params.disabled_events
  | when True: push Actions EventActions
| EventActions <= EventActions.flip.join

world.update =
| $main.music{playlist_advance}
| when EventActions.end: $process_events
| till EventActions.end
  | Effect = EventActions^pop
  | case Effect
    [`{}` EffectName Args @Rest]
      | if Rest.size then Args <= [Args @Rest]
        else case Args [`,` @_]
             | Args <= Args^|@r [`,` X Y]=>[@(r X) Y]; X => [X]
      | $nil.effect{[EffectName,Args] $nil [0 0 0]}
      | when EffectName >< msg: leave //hack to show message before victory
    Else | bad "bad event effect ([Effect])"
| times I 1
  | NextActive = []
  | for U $active.list: U.update
  | while $active.used
    | U = $active.pop
    | when U.active: push U NextActive
  | for U NextActive: $active.push{U}
  | !$cycle + 1
  | ($on_update){}

update_anim Me =
| !$anim_wait - 1
| less $anim_wait > 0
  | when $anim >< attack and $anim_step+1 >< $anim_seq.size:
    | $animate{idle}
  | $anim_step <= ($anim_step+1)%$anim_seq.size
  | $pick_facing{$facing}
  | $anim_wait <= $anim_seq.$anim_step.1


update_path_move Me XYZ =
| Ms = $list_moves{$xyz}.keep{?xyz><XYZ}
| when Ms.end: leave 0
| M = Ms.0
| Us = $world.units_at{XYZ}.skip{?empty}
| Target = if Us.end then 0 else Us.0
| $order.init{type/M.type at/XYZ target/Target}

update_path Me =
| when not $goal or $goal.serial <> $goal_serial or $goal.removed:
  | $goal <= 0
  | $path.heapfree
  | $path <= []
  | leave
| Path = $path
| when Path.end:
  | when $xyz >< $goal.xyz:
    | $goal <= 0
    | leave
  | $path <= $path_to{$goal.xyz}.enheap
| Path = $path
| when Path.end: leave
| XYZ = Path.head.unheap
| $path <= Path.heapfree1
| update_path_move Me XYZ

update_order Me =
| when $ordered.type
  | when $ordered.valid and $ordered.priority >> $next_action.priority:
    | swap $ordered $next_action
  | $ordered.type <= 0

update_fade Me =
| less $delta: leave
| !$alpha+$delta
| when $alpha > 255:
  | $alpha <= 255
  | $delta <= 0
| when $alpha < 0:
  | $alpha <= 0

update_next_action Me =
| less $next_action.type: less $path.end:
  | update_path Me
  | update_order Me
| Cost = $next_action.cost
| if     $next_action.type and $next_action.valid
     and (not $next_action.speed or (not Cost or $owner.mana>>Cost))
  then | !$owner.mana-$next_action.cost
  else
  | if not $next_action.type
      then
    else if Cost and not $owner.mana>>Cost
      then $owner.notify{'Not enough mana.'}
    else if not $next_action.valid
      then $owner.notify{'Cant perform action.'}
    else
  | $next_action.init{type/idle at/$xyz}
| swap $action $next_action
| $next_action.type <= 0
| $next_action.priority <= 0
| $action.start

update_action Me =
| till $action.cycles > 0 // action is done?
  | when $anim<>idle and $anim<>move and
         ($anim_step <> $anim_seq.size-1 or $anim_wait > 1):
    | leave // ensure animation finishes
  | $action.finish
  | update_next_action Me
| $action.update

unit.update =
| when $removed or $active<>1:
  | $active <= 0
  | leave
| update_anim Me
| when $idle: update_path Me
| update_order Me
| update_fade Me
| update_action Me
| 1 // 1 means we are still alive