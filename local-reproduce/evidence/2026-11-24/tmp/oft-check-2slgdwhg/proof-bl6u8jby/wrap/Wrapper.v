(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require OSSVerify.zlib.checksum_fuzzer.Statements.
Require OSSVerify.Proofs.zlib.checksum_fuzzer.plain_halts.Proof.
Definition certified : OSSVerify.zlib.checksum_fuzzer.Statements.plain_halts := OSSVerify.Proofs.zlib.checksum_fuzzer.plain_halts.Proof.plain_halts_holds.
Set Printing Fully Qualified.
Redirect "assumptions" Print Assumptions certified.
