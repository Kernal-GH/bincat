(*
    This file is part of BinCAT.
    Copyright 2014-2017 - Airbus Group

    BinCAT is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or (at your
    option) any later version.

    BinCAT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with BinCAT.  If not, see <http://www.gnu.org/licenses/>.
*)

module Make(D: Domain.T)(Stubs: Stubs.T with type domain_t := D.t) =
struct
  open Asm

  let reg r = V (T (Register.of_name r))

  let const x sz = Const (Data.Word.of_int (Z.of_int x) sz)

  let tbl: (Data.Address.t, import_desc_t) Hashtbl.t = Hashtbl.create 5

  let aapcs_calling_convention = {
    return = reg "r0" ;
    callee_cleanup = (fun _x -> []) ;
    arguments = function
    | 0 -> reg "r0"
    | 1 -> reg "r1"
    | 2 -> reg "r2"
    | 3 -> reg "r3"
    | 4 -> M (Lval (reg "sp"), 32)
    | n -> M ((BinOp (Add, Lval (reg "sp"), const ((n-5)*4) 32)), 32) ;
  }


  let typing_rule_stmts_from_name name =
    try
      let _rule = Hashtbl.find Config.typing_rules name in
      [], []
    with
    | _ -> [], []

  let stub_stmts_from_name name callconv=
    if  Hashtbl.mem Stubs.stubs name then
      [
        Directive (Stub (name, callconv)) ;
        Directive (Forget (reg "r1")) ;
        Directive (Forget (reg "r2")) ;
        Directive (Forget (reg "r3")) ;
      ]

    else
      [
        Directive (Forget (reg "r0")) ;
        Directive (Forget (reg "r1")) ;
        Directive (Forget (reg "r2")) ;
        Directive (Forget (reg "r3")) ;
      ]

  let init_imports () =
    let cc = aapcs_calling_convention in
    Hashtbl.iter (fun adrs (libname,fname) ->
      let typing_pro,typing_epi = Rules.typing_rule_stmts fname cc in
      let tainting_pro,tainting_epi = Rules.tainting_rule_stmts libname fname cc in
      let stub_stmts = stub_stmts_from_name fname cc in
      let fundesc:Asm.import_desc_t = {
        name = fname ;
        libname = libname ;
        prologue = typing_pro @ tainting_pro ;
        stub = stub_stmts ;
        epilogue = typing_epi @ tainting_epi ;
        ret_addr = Lval(reg "lr") ;
      } in
      Hashtbl.replace tbl (Data.Address.global_of_int adrs) fundesc
    ) Config.import_tbl



  let init () =
    Stubs.init ();
    init_imports ()


end

