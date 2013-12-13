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

(** Disk persistence. *)

module type S = sig

  val path: string
  (** The path to the filestystem root. *)

end

module A (S: S) (K: IrminKey.BINARY): IrminStore.A_BINARY
(** Create an append-only store with disk persistence at a given
    path. *)

module M (S: S) (K: IrminKey.S): IrminStore.M_BINARY
(** Create a mutable store with disk persistence at the given path. *)

val simple: string -> (module Irmin.SIMPLE)
(** Simple store stored on the filesystem. *)