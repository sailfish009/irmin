(*
 * Copyright (c) 2013 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Cmdliner
open Irmin.Simple

let global_option_section = "COMMON OPTIONS"

let pr_str = Format.pp_print_string

let value_conv =
  let parse str = `Ok (Value.create str) in
  let print ppf v = pr_str ppf (Value.dump v) in
  parse, print

let tag_conv =
  let parse str = `Ok (Tag.of_string str) in
  let print ppf tag = pr_str ppf (Tag.to_string tag) in
  parse, print

let source_conv =
  let parse str =
    if str = ":" then `Ok (Irmin.memory ())
    else if Sys.file_exists str && not (Sys.is_directory str) then
      `Ok (Irmin.client str)
    else
      `Ok (Irmin.fs str) in
  let print ppf (module S: Irmin.STORE) =
    pr_str ppf S.name in
  parse, print

let value =
  let doc =
    Arg.info ~docv:"VALUE" ~doc:"Value to add." [] in
  Arg.(required & pos 0 (some value_conv) None & doc)

let queue ?(source=["s";"source"]) () =
  let source =
    let doc =
      Arg.info ~docv:"SOURCE" ~doc:"Queue source." source in
    Arg.(value & opt source_conv (Irmin.fs ".irmin") & doc) in
  let in_memory =
    let doc = Arg.info ~doc:"In-memory source. Equivalent to `source :`"
        ["m";"in-memory"] in
    Arg.(value & flag & doc) in
  let front =
    let doc =
      Arg.info ~docv:"FRONT" ~doc:"Tags of front elements." ["f";"front"] in
    Arg.(value & opt tag_conv IrminQueue.default_front & doc) in
  let back =
    let doc =
      Arg.info ~docv:"BACK" ~doc:"Tags of back elements." ["b";"back"] in
    Arg.(value & opt tag_conv IrminQueue.default_back & doc) in
  let create front back source in_memory =
    let source = if in_memory then Irmin.memory () else source in
    IrminQueue.create ~front ~back source in
  Term.(pure create $ front $ back $ source $ in_memory)

let run t =
  Lwt_unix.run begin
    try_lwt t
    with IrminFS.Error _ -> exit 2
  end

(* INIT *)
let init_doc = "Initialize a queue."
let init =
  let doc = init_doc in
  let man = [
    `S "DESCRIPTION";
    `P init_doc;
  ] in
  let daemon =
    let doc =
      Arg.info ~docv:"Unix socket filename." ~doc:"Start an Irminsule server."
        ["d";"daemon"] in
    Arg.(value & opt (some string) None  & doc) in
  let init t daemon =
    run begin
      lwt () = IrminQueue.init t in
      match daemon with
      | None      -> Lwt.return ()
      | Some file -> IrminQueue.server t ~limit:10 file
    end in
  Term.(pure init $ queue () $ daemon),
  Term.info "init" ~doc ~man

(* ADD *)
let add_doc = "Add an element at the end of the queue."
let add =
  let doc = add_doc in
  let man = [
    `S "DESCRIPTION";
    `P add_doc;
  ] in
  let add t value =
    run begin
      IrminQueue.add t value
    end in
  Term.(pure add $ queue () $ value),
  Term.info "add" ~doc ~man

(* WATCH *)
let watch_doc = "Watch a queue."
let watch =
  let doc = watch_doc in
  let man = [
    `S "DESCRIPTION";
    `P watch_doc;
  ] in
  let watch t =
    run begin
      IrminQueue.watch t
    end in
  Term.(pure watch $ queue ()),
  Term.info "watch" ~doc ~man

(* TAKE *)
let take_doc = "Removes and returns the first element in the queue."
let take =
  let doc = take_doc in
  let man = [
    `S "DESCRIPTION";
    `P take_doc;
  ] in
  let take t =
    run begin
      lwt value = IrminQueue.take t in
      Printf.printf "%s" (Value.pretty value);
      Lwt.return ()
    end in
  Term.(pure take $ queue ()),
  Term.info "take" ~doc ~man

(* PEEK *)
let peek_doc = "Returns the first element in the queue, without removing it from \
                the queue."
let peek =
  let doc = peek_doc in
  let man = [
    `S "DESCRIPTION";
    `P peek_doc;
  ] in
  let peek t =
    let elt = run begin
        IrminQueue.peek t
      end in
    Printf.printf "%s\n" (Value.pretty elt) in
  Term.(pure peek $ queue ()),
  Term.info "peek" ~doc ~man

(* LIST *)
let list_doc = "List the queue contents."
let list =
  let doc = list_doc in
  let man = [
    `S "DESCRIPTION";
    `P list_doc;
  ] in
  let list t =
    run begin
      lwt values = IrminQueue.to_list t in
      let blobs = List.map (fun v -> Value.dump v) values in
      List.iter (Printf.printf "%s\n") blobs;
      Lwt.return ()
    end in
  Term.(pure list $ queue ()),
  Term.info "list" ~doc ~man

(* PULL *)
let pull_doc = "Pull changes between queues."
let pull =
  let doc = pull_doc in
  let man = [
    `S "DESCRIPTION";
    `P pull_doc;
  ] in
  let pull t origin =
    run begin
      IrminQueue.pull t ~origin
    end in
  Term.(pure pull $ queue () $ queue ~source:["origin"] ()),
  Term.info "pull" ~doc ~man

(* CLONE *)
let clone_doc = "Clone an existing queue."
let clone =
  let doc = clone_doc in
  let man = [
    `S "DESCRIPTION";
    `P clone_doc;
  ] in
  let clone t origin =
    run begin
      IrminQueue.clone t ~origin
    end in
  Term.(pure clone $ queue () $ queue ~source:["origin"] ()),
  Term.info "clone" ~doc ~man

(* HELP *)
let help =
  let doc = "Display help about Irminsule and Irminsule commands." in
  let man = [
    `S "DESCRIPTION";
     `P "Prints help about Irminsule commands.";
     `P "Use `$(mname) help topics' to get the full list of help topics.";
  ] in
  let topic =
    let doc = Arg.info [] ~docv:"TOPIC" ~doc:"The topic to get help on." in
    Arg.(value & pos 0 (some string) None & doc )
  in
  let help man_format cmds topic = match topic with
    | None       -> `Help (`Pager, None)
    | Some topic ->
      let topics = "topics" :: cmds in
      let conv, _ = Arg.enum (List.rev_map (fun s -> (s, s)) topics) in
      match conv topic with
      | `Error e                -> `Error (false, e)
      | `Ok t when t = "topics" -> List.iter print_endline cmds; `Ok ()
      | `Ok t                   -> `Help (man_format, Some t) in
  Term.(ret (pure help $Term.man_format $Term.choice_names $topic)),
  Term.info "help" ~doc ~man

let default =
  let doc = "Irminsule, the database that never forgets." in
  let man = [
    `S "DESCRIPTION";
    `P "TODO";
    `P "Use either $(b,$(mname) <command> --help) or $(b,$(mname) help <command>) \
        for more information on a specific command.";
  ] in
  let usage _ =
    Printf.printf
      "usage: irmin [--version]\n\
      \             [--help]\n\
      \             <command> [<args>]\n\
      \n\
      The most commonly used irminsule commands are:\n\
      \    init    %s\n\
      \    add     %s\n\
      \    take    %s\n\
      \    peek    %s\n\
      \    watch   %s\n\
      \    list    %s\n\
      \    clone   %s\n\
      \    pull    %s\n\
      \n\
      See `irmin help <command>` for more information on a specific command.\n%!"
      init_doc add_doc take_doc peek_doc watch_doc list_doc clone_doc
      pull_doc in
  Term.(pure usage $ (pure ())),
  Term.info "irmin"
    ~version:IrminVersion.current
    ~sdocs:global_option_section
    ~doc
    ~man

let commands = [
  init;
  add;
  take;
  peek;
  watch;
  list;
  clone;
  pull;
]

let () =
  match Term.eval_choice default commands with
  | `Error _ -> exit 1
  | _ -> ()