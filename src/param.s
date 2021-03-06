use util

load_params2 File =
| less File.exists: bad "cant open [File]"
| Xs = File.get.utf8.parse{src File}^|$_ [[]] => []
| map Key,Value Xs{?1.0,?2.0}
  | case Value
    [`,` A B]
      | Value <= Value^| @r [`,` A B] => [@A^r B]
                       | X => [X]
      | Value <= Value{(normalize_curly ?)}
    [`{}` Name Args @Rest]
      | Value <= normalize_curly Value
      | Value <= [Value]
    Else | Value
  | Key,Value

load_params Folder =
| @table: map BankName Folder.folders
  | RootParamsFile = "[Folder][BankName].txt"
  | RootParams = if RootParamsFile.exists
                 then @table: load_params2 RootParamsFile
                 else t
  | BankFolder = "[Folder][BankName]/"
  | Bank = @table: map Name BankFolder.urls.keep{is.[@_ txt]}{?1}
    | Params = RootParams.deep_copy
    | KVs = load_params2 "[BankFolder][Name].txt"
    | case KVs
      [[proto _] @_] | Params <= KVs.table
      Else | Params <= RootParams.deep_copy
           | for K,V KVs: Params.K <= V
    | Params.bank <= BankName
    | Params.name <= Name
    | Params.filepath <= "[BankFolder][Name]"
    | Name,Params
  | BankName,Bank

extract_params_authors Params =
| Authors = t
| for BankName,Items Params: for Name,Item Items
  | Author = Item.author
  | Origin = Item.origin
  | when got Author:
    | /*when no Origin:*/ Origin <= "[BankName]/[Name]"
    | less Author.is_list: Author <= [Author]
    | less Origin.is_list: Origin <= [Origin]
    | for A Author
      | when no Authors.A: Authors.A <= []
      | for O Origin: push O Authors.A
| for K,V Authors: Authors.K <= V.uniq
| Authors

params_handle_vars Me =
| Main = $params.main
| for BName,Bank $params: for PName,Params Bank: for Key,Value Params:
  | case Value [`.` SPName SKey]
    | less got Main.SPName and got Main.SPName.SKey:
      | bad "[BName]/[PName].txt/[Key]: missing main/[SPName].txt/[SKey]"
    | $params.BName.PName.Key <= Main.SPName.SKey

params_handle_prototypes Me =
| for BName,Bank $params: for PName,Params Bank: when got Params.proto:
  | SBName = BName
  | SPName = Params.proto
  | case SPName B,P:
    | SBName <= B
    | SPName <= P
  | Proto = $params.SBName.SPName.deep_copy
  | for K,V Params: less K><proto: Proto.K <= V
  | Bank.PName <= Proto

type act{name title/0 icon/No hotkey/0 hint/0 tab/0 room/0
         lore/0 cost/0 ap/1 cool/0 needs/[]
         priority/50 range/0 speed/4 repeat/0
         affects/unit targets/seen before/[] impact/Impact after/[]}
  title/Title
  icon/Icon
  hotkey/Hotkey //keyboard shortcut
  hint/Hint //hint for AI: harm (single unit), harm_all (all units)
            //             boost(single unit), boost_allies(all allies),
            //             heal_allies, morph
  tab/Tab //UI tab where this action appears
  room/Room // this act places room scaffolds
  lore/Lore //amount of lore required to research this action
  cost/Cost //how much to cast it
  ap/Ap //action points
  cool/Cool //action cooldown
  needs/Needs //list of dependencies
  priority/Priority
  range/Range //range
  speed/Speed //number of cycles before unit can act again
  repeat/Repeat //repeat action, while possible (i.e. tree is not chopped)
  affects/Affects //what it can target: self, unit, tile, any
                  //also allows prefixes: `(outdoor),` `(water),`
  targets/Targets //seen=requires line of sight, any=any explored cell
  before/Before
  impact/Impact
  after/After
  enabled/#FFFFFF //which players have access to this action
  flags //unit flags this actions sets up
  before_table
  after_table
  icon_gfx //icon graphics for fast access
| $before_table <= $before.table
| $after_table <= $after.table
| when $cool>0: $before <= [[cool $cool] @$before]
| less $title: $title <= $name.replace{_ ' '}
| Flags = []
| for E [@$before @$after]: case E [add Name]: push Name Flags
| $flags <= Flags

params_handle_acts Me =
| Acts = $params.acts
| for Name,Act Acts: Acts.Name <= act Name @Act.list.join

main.load_params =
| $params <= load_params "[$data]params/"
| params_handle_vars Me
| params_handle_prototypes Me
| params_handle_acts Me

export load_params extract_params_authors
