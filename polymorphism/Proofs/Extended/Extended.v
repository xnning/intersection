Require Import String.
Require Import Coq.Structures.Equalities.
Require Import Coq.MSets.MSetInterface.
Require Import Arith.
Require Import Setoid.
Require Import Coq.Program.Equality.
Require Import SystemF.
Require Import Typing.

Module Extended
       (Import VarTyp : UsualDecidableTypeFull)
       (Import set : MSetInterface.S).

Module MTyping := MTyping(VarTyp)(set).
Export MTyping.

(* Notes:

The syntax is encoded using Charguéraud's Locally nameless representation:

http://www.chargueraud.org/softs/ln/

We annotate the Coq theorems with the correnposing lemmas/theorems in the paper. 
The reader can just look for:

Lemma 4

for example, to look for the proof of lemma 4 in the paper.

All lemmas and theorems are complete: there are no uses of admit or Admitted,
with the exceptions of "tlam" and "tylam" due to a technical limitation.

*)


Lemma ortho_ax_sym : forall A B, OrthoAx A B -> OrthoAx B A.
Proof.
  intros.
  destruct H as [a [b c]].
  unfold OrthoAx.
  auto.
Qed.

Lemma ortho_sym : forall Gamma A B, Ortho Gamma A B -> Ortho Gamma B A.
Proof.
  intros Gamma A B HOrtho.
  induction HOrtho; auto.
  - apply_fresh OForAll as x; apply H0; not_in_L x.
  - apply OVarSym with (A := A); auto.
  - apply OVar with (A := A); auto.
  - apply ortho_ax_sym in H; now apply OAx.
Qed.
  
Lemma ortho_and_l : forall Gamma t1 t2 t0, Ortho Gamma (And t1 t2) t0 -> Ortho Gamma t1 t0.
Proof.
  intros.
  dependent induction H; auto.
  - inversion H1; subst.
    apply OVarSym with (A := A); auto.
    apply sound_sub in H0.
    destruct H0.
    inversion H0; subst.
    apply complete_sub.
    eexists; apply H7.
    inversion H3.
    inversion H3.
  - orthoax_inv_l.
Qed.

Lemma ortho_and_r : forall Gamma t1 t2 t0, Ortho Gamma (And t1 t2) t0 -> Ortho Gamma t2 t0.
Proof.
  intros.
  dependent induction H; auto.
  - inversion H1; subst.
    apply OVarSym with (A := A); auto.
    apply sound_sub in H0.
    destruct H0.
    inversion H0; subst.
    apply complete_sub.
    eexists; apply H9.
    inversion H3.
    inversion H3.
  - orthoax_inv_l.
Qed.

Lemma wfenv_no_refl : forall Gamma x, WFEnv Gamma -> not (List.In (x, TyDis (PFVarT x)) Gamma).
Proof.
  intros.
  induction H.
  - auto.
  - unfold not, extend; simpl in *; intros.
    destruct H2.
    inversion H2; subst.
    apply H0; simpl.
    now apply MSetProperties.Dec.F.singleton_2.
    contradiction.
  - unfold not, extend; simpl; intros [a | b]; apply IHWFEnv.
    inversion a. auto.
Qed.

Lemma wfenv_no_var_sub :
  forall Gamma x A, WFEnv Gamma -> Sub A (PFVarT x) -> not (List.In (x, TyDis A) Gamma).
Proof.
  intros.
  induction H.
  - auto.
  - unfold not, extend; simpl in *; intros.
    destruct H3.
    inversion H3; subst.
    inversion H0.
    clear IHWFEnv H2 H0 H.
    dependent induction H4.
    + simpl in *; apply IHsub; not_in_L x.
    + simpl in *; apply IHsub; not_in_L x.
    + apply H1; simpl; now apply MSetProperties.Dec.F.singleton_2.
    + contradiction.
  - unfold not, extend; simpl; intros [a | b]; apply IHWFEnv.
    inversion a. auto.
Qed.

Inductive TopLike : PTyp -> Prop :=
  | TLTop : TopLike Top
  | TLAnd : forall t1 t2, TopLike t1 -> TopLike t2 -> TopLike (And t1 t2)
  | TLFun : forall t1 t2, TopLike t2 -> TopLike (Fun t1 t2)
  | TLForAll : forall L d t,
                 (forall x, not (In x L) -> TopLike (open_typ_source t (PFVarT x))) ->
                 TopLike (ForAll d t).

Hint Constructors TopLike.

Lemma toplike_subst :
  forall t u z, PType u -> TopLike t -> TopLike (subst_typ_source z u t).
Proof.
  intros t u z HTypu HBLt.
  induction HBLt; intros; simpl in *; auto.
  (* TLForAll *)
  apply_fresh TLForAll as x.
  rewrite subst_typ_source_open_source_var; auto.
  apply H0.
  not_in_L x.
  not_in_L x.
Qed.

Lemma fresh_top :
  forall t x, ~(In x (fv_ptyp t)) -> TopLike (open_typ_source t (PFVarT x)) ->
         forall y, ~(In y (fv_ptyp t)) -> TopLike (open_typ_source t (PFVarT y)).
Proof.
  intros.
  destruct (VarTyp.eq_dec x y).
  - subst; auto.
  - rewrite subst_typ_source_intro with (x := x); auto.
    apply toplike_subst; auto.
Qed.

Lemma toplike_dec : forall t, PType t -> (TopLike t) \/ (not (TopLike t)).
Proof.
  intros t Ht.
  induction Ht; intros.
  - right; unfold not; intros HInv; inversion HInv.
  - right; unfold not; intros HInv; inversion HInv.
  - inversion IHHt2; auto.
    right; unfold not; intros HInv; inversion HInv; subst.
    contradiction.
  - destruct IHHt1; destruct IHHt2; subst; auto.
    right. unfold not. intros. inversion H1; subst. contradiction.
    right. unfold not. intros. inversion H1; subst. contradiction.
    right. unfold not. intros. inversion H1; subst. contradiction.
  - (* right; unfold not; intros HInv; inversion HInv. *)
    pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    apply H0 in Ha.
    destruct Ha.
    left; apply_fresh TLForAll as y.
    apply fresh_top with (x := x); auto.
    not_in_L x.
    not_in_L y.
    right; unfold not; intros HInv; inversion HInv; subst.
    apply H1.
    pick_fresh y.
    assert (Ha : ~ In y L0) by not_in_L y.
    apply H3 in Ha.
    apply fresh_top with (x := y); auto.
    not_in_L y.
    not_in_L x.
  - left; apply TLTop.
Qed.

Lemma ortho_no_sub :
  forall Gamma A B, WFTyp Gamma A -> WFTyp Gamma B -> Ortho Gamma A B -> ~ TopLike B -> not (Sub A B).
Proof.
  intros Gamma A B WFA WFB HOrtho HNotTL HSub.

  inversion HSub.
  generalize dependent Gamma.
  induction H; intros.
  - inversion HOrtho; subst. destruct H as [a [b c]]; now apply c.
  - inversion HOrtho; subst.
    inversion WFA; inversion WFB; subst.
    apply IHsub2 with (Gamma := Gamma); auto.
    inversion HSub. inversion H1; subst.
    eexists; apply H13.
    destruct H1 as [a [b c]]; now apply c.
  - inversion WFB; subst.
    assert (Ha : ~ TopLike t1 \/ ~ TopLike t2).
    apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; auto.
    destruct Ha.
    apply IHsub1 with (Gamma := Gamma); auto.
    eexists; apply H.
    apply ortho_sym.
    apply ortho_and_l with (t2 := t2); auto.
    now apply ortho_sym.
    apply IHsub2 with (Gamma := Gamma); auto.
    eexists; apply H0.
    apply ortho_sym.
    apply ortho_and_r with (t1 := t1); auto.
    now apply ortho_sym.    
  - inversion WFA; subst; apply IHsub with (Gamma := Gamma); auto.
    eexists; apply H.
    apply ortho_and_l with (t2 := t2); auto.
  - inversion WFA; subst; apply IHsub with (Gamma := Gamma); auto.
    eexists; apply H.
    apply ortho_and_r with (t1 := t1); auto.
  - inversion HOrtho; subst.
    apply wfenv_no_var_sub with (Gamma := Gamma) (A := A) (x := v); auto.
    now apply wf_gives_wfenv in WFA.
    now apply sound_sub.
    apply wfenv_no_var_sub with (Gamma := Gamma) (A := A) (x := v); auto.
    now apply wf_gives_wfenv in WFA.
    now apply sound_sub.
    destruct H as [a [b c]]; now apply c.    
  - inversion WFA; inversion WFB; subst.
    inversion HSub.
    inversion H2; subst.
    inversion HOrtho; subst.
    pick_fresh x.
    eapply H0 with (x := x).
    not_in_L x.
    unfold not; intros HH; apply HNotTL.
    apply_fresh TLForAll as y.
    apply fresh_top with (x := x).
    not_in_L x.
    assumption.
    not_in_L y.
    eexists; apply H8.
    not_in_L x.
    apply H5.
    not_in_L x.
    apply H10.
    not_in_L x.
    apply H7.
    not_in_L x.
    destruct H3 as [a [b HH]]; now apply HH.
  - auto.
Qed.

Lemma usub_top : forall D, usub Top D -> TopLike D.
  intros. dependent induction H. apply TLAnd; auto. apply TLTop.
Defined.

(* Unique subtype contributor: Lemma 2 *)

Lemma uniquesub :
  forall Gamma A B C, WFTyp Gamma A -> WFTyp Gamma B -> ~ TopLike C ->
             Ortho Gamma A B -> Sub (And A B) C -> not (Sub A C /\ Sub B C).
Proof.
  intros Gamma A B C WFA WFB HNotTL HOrtho HSubAnd.
  unfold not; intros [HSubA HSubB].
  generalize dependent C.
  dependent induction HOrtho; intros.
  - induction C;
    try now inversion WFA;
    inversion HSubA; inversion H5; subst; [ eapply IHHOrtho1 | eapply IHHOrtho2 ];
    eauto; unfold Sub; eauto.
    + inversion HSubA; inversion H; subst.
      inversion HSubB; inversion H0; subst.
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; auto; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; auto; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      inversion H2.
      inversion H2.
      inversion H3.
      inversion H3.
    + now apply HNotTL.
  - induction C;
    try now inversion WFB; subst;
    inversion HSubB; inversion H; subst; [ eapply IHHOrtho1 | eapply IHHOrtho2 ];
    eauto; unfold Sub; eauto.
    + inversion HSubA; inversion H; subst.
      inversion HSubB; inversion H0; subst.
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; auto; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; auto; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      inversion H6.
      inversion H6.
      inversion H1.
      inversion H1.
    + now apply HNotTL.
  - induction C; try (now (inversion HSubA as [x HInv]; inversion HInv)).
    + inversion WFA; subst; inversion WFB; subst.
      inversion HSubA; inversion H; subst.
      inversion HSubB; inversion H0; subst.
      assert (Ha : ~ TopLike C2) by (unfold not; auto).
      eapply IHHOrtho; auto; [ apply Ha
                             | apply sand2; unfold Sub; eauto
                             | unfold Sub; eauto
                             | unfold Sub; eauto ].
    + assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      inversion WFA; subst; inversion WFB; subst.
      inversion HSubA; inversion H; subst.
      inversion HSubB; inversion H0; subst.
      destruct Ha.
      apply IHC1; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
    + now apply HNotTL.
  - induction C; try (now (inversion HSubA as [x HInv]; inversion HInv)).
    + inversion HSubA; inversion H1; subst.
      inversion HSubB; inversion H2; subst.
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.      
    + inversion HSubA; inversion H1; subst.
      inversion HSubB; inversion H2; subst.
      inversion WFA; inversion WFB; subst.
      pick_fresh x.
      clear IHC1; clear IHC2; clear HSubAnd.
      eapply H0 with (x := x) (C := open_typ_source C2 (PFVarT x)).
      not_in_L x; apply H7.
      apply H9; not_in_L x.
      apply H15; not_in_L x. 
      unfold not; intros; apply HNotTL.
      apply_fresh TLForAll as y.
      apply fresh_top with (x := x); auto.
      not_in_L x.
      not_in_L y.
      apply sand2.
      eexists; apply H7.
      not_in_L x.
      apply wf_gives_types_source with (Gamma := (extend x (TyDis C1) Gamma)).
      apply H15; not_in_L x.
      eexists; apply H7; not_in_L x.
      eexists; apply H6; not_in_L x.
    + now apply HNotTL.
  - induction C; try (now (inversion HSubA as [z HInv]; inversion HInv)).
    + destruct HSubA as [c HsubA]; inversion HsubA; subst.
      destruct HSubB as [c HsubB]; inversion HsubB; subst.
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      inversion H3.
      inversion H3.
    + clear HSubAnd.
      destruct HSubA as [c HsubA]; inversion HsubA; subst.
      assert (Ha : Ortho Gamma ty (PFVarT v)).
      apply OVarSym with (A := A); auto.
      apply ortho_no_sub in Ha.
      contradiction.
      auto.
      auto.
      unfold not; intros HInv; inversion HInv.
    + now apply HNotTL.
  (* same as above (var_sym) *)
  - induction C; try (now (inversion HSubB as [z HInv]; inversion HInv)).
    + destruct HSubA as [c HsubA]; inversion HsubA; subst.
      destruct HSubB as [c HsubB]; inversion HsubB; subst.
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      inversion H3.
      inversion H3.
    + clear HSubAnd.
      destruct HSubB as [c HsubB]; inversion HsubB; subst.
      assert (Ha : Ortho Gamma ty (PFVarT v)).
      apply OVarSym with (A := A); auto.
      apply ortho_no_sub in Ha.
      contradiction.
      auto.
      auto.
      unfold not; intros HInv; inversion HInv.
    + now apply HNotTL.
  - apply complete_sub in HSubA; apply usub_top in HSubA; contradiction.
  - apply complete_sub in HSubB; apply usub_top in HSubB; contradiction.
  - destruct H as [ PTypHd1 [ PTypHd2 PTypHd3 ]].
    induction C.
    + inversion HSubA as [x HsA]; inversion HsA; subst; try orthoax_inv PTypHd1.
      inversion HSubB as [x HsB]; inversion HsB; subst; try orthoax_inv PTypHd2.
      apply PTypHd3; auto.
    + inversion HSubA as [x HsA]; inversion HsA; subst; try orthoax_inv PTypHd1.
      inversion HSubB as [x HsB]; inversion HsB; subst; try orthoax_inv PTypHd2.
      apply PTypHd3; auto.
    + inversion HSubA as [x HInv1]; inversion HInv1; subst; try (now inversion H0).
      inversion HSubB as [x HInv2]; inversion HInv2; subst; try (now inversion H0).
      assert (Ha : ~ TopLike C1 \/ ~ TopLike C2).
      apply Classical_Prop.not_and_or; unfold not; intros HH; destruct HH; eauto.
      destruct Ha.
      apply IHC1; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.
      apply IHC2; unfold Sub; eauto.
      apply sand2; unfold Sub; eauto.      
    + inversion HSubA as [x HsA]; inversion HsA; subst; inversion H0.
    + inversion HSubA as [x HsA]; inversion HsA; subst; try orthoax_inv PTypHd1.
    + inversion HSubA as [x HsA]; inversion HsA; subst; try orthoax_inv PTypHd1.
      inversion HSubB as [x HsB]; inversion HsB; subst; try orthoax_inv PTypHd2.
      apply PTypHd3; auto.
    + now apply HNotTL.
Qed.

(*** Move to SystemF ***)

Lemma open_rec_type_term_core2 :
  forall (t : SExp var) (j : nat) (v : STyp) (i : nat) (u : SExp var),
  open_rec_typ_term j v t = open_rec_typ_term j v ({i ~> u} t) ->
  t = {i ~> u} t.
Proof.
  intro t; induction t; intros; simpl in *; auto.
  - destruct (i =? n).
    destruct u; simpl in *; auto; now inversion H.
    reflexivity.
  - inversion H; apply IHt in H1; now rewrite <- H1.
  - inversion H; apply IHt1 in H1; apply IHt2 in H2; rewrite <- H1; rewrite <- H2;
    reflexivity.
  - inversion H; apply IHt1 in H1; apply IHt2 in H2; rewrite <- H1; rewrite <- H2;
    reflexivity.
  - inversion H; apply IHt in H1; now rewrite <- H1.
  - inversion H; apply IHt in H1; now rewrite <- H1.
  - inversion H; apply IHt in H1; now rewrite <- H1.
  - inversion H; apply IHt in H1; now rewrite <- H1.
Qed.

Lemma open_rec_type_term_core3 :
  forall t n m u x,
    {m ~> STFVar elt x} t = open_rec_typ_term n u ({m ~> STFVar elt x} t) ->
    t = open_rec_typ_term n u t.
Proof.
  intro t; induction t; intros; simpl in *; auto.
  - inversion H; apply IHt in H1; rewrite <- H1; auto.
  - inversion H; apply IHt1 in H1; apply IHt2 in H2;
    rewrite <- H1; rewrite <- H2; auto.
  - inversion H; apply IHt1 in H1; apply IHt2 in H2;
    rewrite <- H1; rewrite <- H2; auto.
  - inversion H; apply IHt in H1; rewrite <- H1; auto.
  - inversion H; apply IHt in H1; rewrite <- H1; auto.
  - inversion H; apply IHt in H1; rewrite <- H1; auto.
  - inversion H; apply IHt in H1; rewrite <- H1; rewrite <- H2; rewrite <- H2; auto.
Qed.

Lemma open_rec_typ_term_core4 : forall t j v i u, i <> j ->
  open_rec_typ_term j v t = open_rec_typ_term i u (open_rec_typ_term j v t) ->
  t = open_rec_typ_term i u t.
Proof.
  intro t; induction t; intros; simpl; auto.
  - simpl in H0; inversion H0.
    erewrite <- IHt; eauto.
  - simpl in H0; inversion H0.
    erewrite <- IHt1.
    erewrite <- IHt2.
    reflexivity.
    apply H.
    apply H3.
    apply H.
    apply H2.
  - simpl in H0; inversion H0.
    erewrite <- IHt1.
    erewrite <- IHt2.
    reflexivity.
    apply H.
    apply H3.
    apply H.
    apply H2.
  - simpl in H0; inversion H0.
    erewrite <- IHt.
    reflexivity.
    apply H.
    apply H2.
  - simpl in H0; inversion H0.
    erewrite <- IHt.
    reflexivity.
    apply H.
    apply H2.
  - simpl in H0; inversion H0.
    erewrite <- IHt.
    reflexivity.
    apply not_eq_S.
    apply H.
    apply H2.
  - simpl in H0; inversion H0.
    erewrite <- IHt.
    apply open_rec_typ_core in H3.
    now rewrite <- H3.
    auto.
    apply H.
    apply H2.
Qed.

Lemma open_rec_typ_term_term :
  forall t u, STTerm t -> forall k, t = open_rec_typ_term k u t.
Proof.
  intros t u HT.
  induction HT; intros; simpl; auto.
  - unfold open in *.
    pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    apply H0 with (k := k) in Ha.
    apply open_rec_type_term_core3 in Ha.
    now rewrite <- Ha.
  - rewrite <- IHHT1; rewrite <- IHHT2; auto.
  - rewrite <- IHHT1; rewrite <- IHHT2; auto.
  - rewrite <- IHHT; auto.
  - rewrite <- IHHT; auto.
  - pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    apply H0 with (k := S k) in Ha.
    unfold open_typ_term in *.
    apply open_rec_typ_term_core4 in Ha.
    now rewrite <- Ha.
    auto.
  - rewrite <- IHHT; auto.
    rewrite <- open_rec_type; auto.
Qed.
 
Definition body_typ_term t :=
  exists L, forall x, ~ In x L -> STTerm (open_typ_term t (STFVarT x)).

Lemma term_abs_to_body_typ_term : forall t1, 
  STTerm (STTLam _ t1) -> body_typ_term t1.
Proof. intros. unfold body_typ_term. inversion H; subst. eauto. Qed.

Lemma body_typ_term_to_term_abs : forall t1, 
  body_typ_term t1 -> STTerm (STTLam _ t1).
Proof. intros. inversion H. eapply STTerm_TLam. apply H0. Qed.

Lemma ac_inl_term : forall e t r, and_coercion e t (inl r) -> STTerm r.
Proof.
  intros.
  dependent induction H; auto.
  - apply_fresh STTerm_Lam as x.
    unfold open; rewrite <- open_rec_term; auto.
  - pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    apply H0 in Ha.
    apply body_typ_term_to_term_abs.
    unfold body_typ_term.
    exists (fv e1).
    intros; unfold open_typ_term; rewrite <- open_rec_typ_term_term; auto.
Qed.

(* and_coercion lemmas *)

Lemma ac_inr_term : forall e t r, STTerm e -> and_coercion e t (inr r) -> STTerm r.
Proof. intros; apply ac_inr_inv_eq in H0; now subst. Qed.
  
Lemma and_coercion_proj1_term :
  forall t0 (c : SExp var) c',
    PType t0 ->
    STTerm c ->
    and_coercion ((STApp _ c (STProj1 _ (STBVar _ 0)))) t0 c' ->
    STTerm (STLam _ (join_sum c')).
Proof.
  intros.
  apply_fresh STTerm_Lam as x; unfold open; simpl.
  destruct c'; simpl.
  apply ac_inl_term in H1.
  rewrite <- open_rec_term; auto.
  apply ac_inr_inv_eq in H1.
  rewrite <- H1.
  simpl.
  apply STTerm_App; auto.
  rewrite <- open_rec_term; auto.
Qed.

Lemma and_coercion_proj2_term :
  forall t0 (c : SExp var) c',
    PType t0 ->
    STTerm c ->
    and_coercion ((STApp _ c (STProj2 _ (STBVar _ 0)))) t0 c' ->
    STTerm (STLam _ (join_sum c')).
Proof.
  intros.
  apply_fresh STTerm_Lam as x; unfold open; simpl.
  destruct c'; simpl.
  apply ac_inl_term in H1.
  rewrite <- open_rec_term; auto.
  apply ac_inr_inv_eq in H1.
  rewrite <- H1.
  simpl.
  apply STTerm_App; auto.
  rewrite <- open_rec_term; auto.
Qed.

Lemma same_coercion :
  forall A, PType A ->
       forall e c1 c2, and_coercion e A c1 -> and_coercion e A c2 -> c1 = c2.
Proof.
  intros A HPT.
  induction HPT; intros.
  - now inversion H; inversion H0.
  - now inversion H; inversion H0.
  - inversion H; inversion H0; subst; eauto.
    + apply f_equal.
      now apply (IHHPT2 _ _ _ H4) in H8; inversion H8.
    + now apply (IHHPT2 _ _ _ H4) in H8; inversion H8.
    + now apply (IHHPT2 _ _ _ H4) in H8; inversion H8.
  - inversion H; inversion H0; subst; eauto.
    + apply f_equal.
      apply (IHHPT1 _ _ _ H3) in H8.
      apply (IHHPT2 _ _ _ H5) in H10.
      inversion H8; inversion H10; now subst.
    + apply (IHHPT1 _ _ _ H3) in H9; inversion H9.
    + apply (IHHPT2 _ _ _ H5) in H9; inversion H9.
    + apply (IHHPT1 _ _ _ H4) in H7; inversion H7.
    + apply (IHHPT2 _ _ _ H4) in H9; inversion H9.
  - inversion H1; inversion H2; subst; eauto.
    + pick_fresh x.
      assert (Ha : @inl _ (SExp var) e1 = inl e0).
      eapply H0 with (x := x).
      not_in_L x.
      apply H6; not_in_L x.
      apply H10; not_in_L x.
      inversion Ha; now subst.
    + pick_fresh x.
      assert (Ha : inl e1 = inr e).
      eapply H0 with (x := x).
      not_in_L x.
      apply H6; not_in_L x.
      apply H10; not_in_L x.
      inversion Ha.
    + pick_fresh x.
      assert (Ha : inl e1 = inr e).
      eapply H0 with (x := x).
      not_in_L x.
      apply H10; not_in_L x.
      apply H6; not_in_L x.
      inversion Ha.
  - inversion H; inversion H0; subst; auto;
    apply (IHHTL _ _ _ H4) in H8; now inversion H8.
Qed.

Lemma and_coercion_inl : 
  forall {t e},
    PType t ->
    TopLike t ->
    exists r, and_coercion e t (inl r).
Proof.
  intros.
  induction H0.
  - exists (STUnit _); auto.
  - inversion H; subst; destruct IHTopLike1, IHTopLike2; eauto.  
  - inversion H; subst.
    apply IHTopLike in H4.
    inversion H4.
    exists (STLam _ x).
    auto.
  - inversion H; subst.
    apply ac_ptype with (e := e) in H.
    destruct H.
    inversion H; subst.
    eauto.
    pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    apply H1 in Ha.
    destruct Ha.
    assert (Ha1 : ~ In x L1) by not_in_L x.
    apply H7 in Ha1.
    assert (HaInv : inl x0 = inr e).
    eapply same_coercion with (A := (open_typ_source t0 (PFVarT x))).
    apply H5; not_in_L x.
    apply H2.
    apply Ha1.
    inversion HaInv.
    apply H5; not_in_L x.
Qed.

Ltac wftyp_to_ok :=
  match goal with
    | H: WFTyp ?Gamma _ |- ok (∥ ?Gamma ∥) => apply ok_map;
        apply wf_gives_wfenv in H; now apply wfenv_to_ok in H
  end.

Ltac env_resolve := auto; now wftyp_to_ok.

Lemma and_coercion_inl_typing :
  forall {t e Gamma r},
    TopLike t ->
    and_coercion e t (inl r) ->
    WFTyp Gamma t ->
    has_type_st (∥ Gamma ∥) r (|t|).  
Proof.
  intros.
  generalize dependent Gamma.
  dependent induction H0; intros; try (now simpl; eauto).
  - simpl; inversion H; inversion H1; subst.
    apply_fresh STTyLam as x.
    apply (IHand_coercion H3) in H9.
    unfold open.
    rewrite <- open_rec_term.
    apply typing_weaken_extend; auto.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    now apply ac_inl_term in H0.
    env_resolve.
  - inversion H; inversion H1; subst; simpl; auto.
  - inversion H; inversion H2; subst; simpl.
    apply_fresh STTyTLam as x.
    unfold open_typ_source in H0.
    assert (Ha : has_type_st (∥ (extend x (TyDis d) Gamma) ∥) e1 (| open_rec_typ_source 0 (PFVarT x) A |)).
    apply H0.
    not_in_L x.
    apply H4.
    not_in_L x.
    apply H9.
    not_in_L x.
    rewrite open_rec_typ_eq_source in Ha.
    simpl in Ha; unfold extend; unfold open_typ; simpl.
    unfold open_typ_term; rewrite <- open_rec_typ_term_term; auto.
    assert (Ha1 : ~ In x L) by not_in_L x.
    apply H1 in Ha1.
    now apply ac_inl_term in Ha1.
Qed.

Lemma and_coercion_inr :
  forall {t} e,
    PType t ->
    not (TopLike t) ->
    and_coercion e t (inr e).
Proof.
  intros.
  generalize dependent e.
  induction H; try simpl; auto.
  - intros; auto 10.
  - intros.
    assert (Ha : ~ TopLike t1 \/ ~ TopLike t2) by
        (apply Classical_Prop.not_and_or; unfold not; intros; apply H0; now apply TLAnd).
    destruct Ha; eauto.
  - intros.
    apply ACForAllR with (L := union L (fv_ptyp t0)).
    intros.
    apply H2.
    not_in_L x.
    unfold not; intros; apply H0.
    apply_fresh TLForAll as x.
    apply fresh_top with (x := x); auto.
    not_in_L x.
    not_in_L y.
  - intros; exfalso; apply H0; apply TLTop.
Qed.


Lemma change_coercion_toplike :
  forall A e1 e2 c, TopLike A -> and_coercion e1 A c -> and_coercion e2 A c.
Proof.
  intros A e1 e2 c HTL HAC.
  generalize dependent e2.
  induction HAC; intros; try now inversion HTL.
  - inversion HTL; subst; auto.
  - inversion HTL; subst.
    apply IHHAC with (e2 := e2) in H0.
    apply ac_inr_inv_eq in H0.
    subst; auto.
  - inversion HTL; subst.
    apply IHHAC1 with (e2 := e3) in H1.
    apply IHHAC2 with (e3 := e3) in H2.
    auto.
  - inversion HTL; subst.
    apply IHHAC with (e2 := e2) in H1.
    apply ac_inr_inv_eq in H1.
    subst; auto.
  - inversion HTL; subst.
    apply IHHAC with (e2 := e2) in H2.
    apply ac_inr_inv_eq in H2.
    subst; auto.
  - inversion HTL; subst.
    eapply ACForAllL with (L := union L L0).
    intros x HNotIn.
    apply H0.
    not_in_L x.
    apply H2.
    not_in_L x.
  - inversion HTL; subst.
    pick_fresh x.
    assert (Ha : ~ In x L) by not_in_L x.
    assert (Ha1 : ~ In x L0) by not_in_L x.
    apply H2 in Ha1.
    apply (H0 _ Ha) with (e2 := e2) in Ha1.
    apply ac_inr_inv_eq in Ha1; subst.
    eapply ACForAllR with (L := union L L0).
    intros y H3.
    apply H0.
    not_in_L y.
    apply H2.
    not_in_L y.
Qed.

(* Coercive subtyping is coeherent: Lemma 3 *)

Lemma sub_coherent :
  forall {A Gamma}, WFTyp Gamma A ->
           forall {B}, WFTyp Gamma B ->
                  forall {C1}, sub A B C1 ->
                          forall {C2}, sub A B C2 -> C1 = C2.
Proof.
  intros.
  generalize dependent C2.
  generalize dependent Gamma.
  (* Case: Int <: Int *)
  induction H1; intros.
  - inversion H2. 
    reflexivity.
  (* Case: Fun t1 t2 <: Fun t3 t4 *)
  - inversion H. inversion H0. inversion H2.
    assert (c2 = c3). apply IHsub2 with (Gamma := Gamma); auto.
    assert (c1 = c0). apply IHsub1 with (Gamma := Gamma); auto.
    now subst.
  (* Case: t <: And t1 t2 *) 
  - inversion H2; inversion H0; subst.
    assert (c1 = c0) by (apply IHsub1 with (Gamma := Gamma); auto).
    assert (c2 = c3) by (apply IHsub2 with (Gamma := Gamma); auto).
    now subst.
    now subst.
    now subst.
  (* Case: And t1 t2 <: t (first) *)
  - inversion H3; subst.
    inversion H5; subst.
    + inversion H.
    + assert (c = c0). apply IHsub with (Gamma := Gamma); auto.
      subst.
      assert (ac0 = ac).
      eapply same_coercion with (A := t0).
      now apply wf_gives_types_source with (Gamma := Gamma).
      apply H16. apply H2.
      now subst.
    + destruct (toplike_dec t0).
      now apply wf_gives_types_source with (Gamma := Gamma).
      apply change_coercion_toplike with
      (e2 := (STApp var c (STProj1 var (STBVar var 0)))) in H16; auto.
      repeat apply f_equal.
      rewrite same_coercion with (e := (STApp var c (STProj1 var (STBVar var 0))))
                                   (c2 := ac) (A := t0); auto.
      now apply wf_gives_types_source with (Gamma := Gamma).
      assert (HSub : Sub (And t1 t2) t0) by (apply sand2; unfold Sub; eauto).
      assert (Ha := uniquesub _ t1 t2 t0 H8 H10 H6 H11 HSub).
      exfalso; apply Ha.
      split; unfold Sub; eauto.
    + inversion H.
  - inversion H3; subst.
    inversion H5; subst.
    + inversion H.
    + destruct (toplike_dec t0).
      now apply wf_gives_types_source with (Gamma := Gamma).
      apply change_coercion_toplike with
      (e2 := (STApp var c (STProj2 var (STBVar var 0)))) in H16; auto.
      repeat apply f_equal.
      rewrite same_coercion with (e := (STApp var c (STProj2 var (STBVar var 0))))
                                   (c2 := ac) (A := t0); auto.
      now apply wf_gives_types_source with (Gamma := Gamma).
      assert (HSub : Sub (And t1 t2) t0) by (apply sand2; unfold Sub; eauto).
      assert (Ha := uniquesub _ t1 t2 t0 H8 H10 H6 H11 HSub).
      exfalso; apply Ha.
      split; unfold Sub; eauto.
    + assert (c = c0). apply IHsub with (Gamma := Gamma); auto.
      subst.
      assert (ac0 = ac).
      eapply same_coercion with (A := t0).
      now apply wf_gives_types_source with (Gamma := Gamma).
      apply H16. apply H2.
      now subst.
    + inversion H.
  - now inversion H2.
  - inversion H2; subst.
    inversion H3; subst.
    inversion H4; subst.
    pick_fresh x.
    assert (Ha : (open_typ_term c (STFVarT x)) = (open_typ_term c0 (STFVarT x))).
    assert (ty := Top).
    eapply H0 with (Gamma := extend x (TyDis d) Gamma).
    not_in_L x.
    apply H8.
    not_in_L x.
    apply H10.
    not_in_L x.
    apply H12.
    not_in_L x.
    assert (c = c0).
    eapply open_typ_term_app_eq with (x := x) (n := 0).
    not_in_L x.
    not_in_L x.
    apply Ha.
    now subst.
  - inversion H2.
    inversion H4.
    inversion H4.
    now subst.    
Qed.

(*
End ExtendedSub.

Module Extended
       (Import VarTyp : UsualDecidableTypeFull)
       (Import set : MSetInterface.S).

Require Import Extended_infrastructure.
Module Infrastructure := Infrastructure(VarTyp)(set).
Export Infrastructure.

Module ExtendedSub := ExtendedSub(VarTyp)(set).
Import ExtendedSub.
 *)

(* Typing lemmas *)

Lemma typing_wf_source_alg:
  forall Gamma t T E dir, has_type_source_alg Gamma t dir T E -> WFTyp Gamma T.
Proof.
  intros Gamma t dir T E H.
  induction H; auto.
  - inversion IHhas_type_source_alg1; assumption.
  - inversion IHhas_type_source_alg; subst.
    apply open_body_wf_type with (d := d); auto.
    unfold body_wf_typ; eauto.
  - pick_fresh x.
    assert (Ha : not (M.In x L)) by (not_in_L x).
    apply WFFun.
    assumption.
    apply H0 in Ha.
    rewrite <- app_nil_l with (l := Gamma).
    eapply wf_strengthen_source with (z := x).
    not_in_L x.
    rewrite app_nil_l; apply Ha.
  - apply_fresh WFForAll as x.
    apply H1.
    not_in_L x.
    auto.
Qed.

Lemma type_correct_alg_terms : forall Gamma E ty e dir, has_type_source_alg Gamma E dir ty e -> PTerm E.
Proof.
  intros.
  induction H; auto.
  - apply PTerm_TApp.
    auto.
    now apply wf_gives_types_source in H.
  - apply_fresh PTerm_Lam as x; auto.
    apply H0; not_in_L x.
  - apply_fresh PTerm_TLam as x.
    apply H1; not_in_L x.
Qed.


Lemma typing_alg_wf_env :
  forall Gamma E dir ty e, has_type_source_alg Gamma E dir ty e -> WFEnv Gamma.
Proof.
  intros.
  induction H; auto.
  - pick_fresh x;
    assert (Ha: not (In x L)) by not_in_L x;
    pose (H0 _ Ha) as HInv;
    inversion HInv; auto.
  - pick_fresh x.
    assert (Ha : not (In x L)) by not_in_L x.
    apply H1 in Ha.
    now inversion Ha.
Qed.
  
(* Ignoring the generated expressions + smart constructors *)

Definition has_ty Gamma e d t := exists E, has_type_source_alg Gamma e d t E.

(* Uniqueness *)

Definition almost_unique (A B : PTyp) (d : Dir) : Prop := 
  match d with
    | Inf => A = B
    | Chk => True (* Is this result useful for checking: exists C, Sub C A /\ Sub C B*)
  end.

Lemma typ_unique : forall Gamma e d t1 E1, has_type_source_alg Gamma e d t1 E1 -> forall t2 E2, has_type_source_alg Gamma e d t2 E2 -> almost_unique t1 t2 d.
intros Gamma e d t1 E1 H.
induction H; intros; unfold almost_unique; auto.
(* case Unit *)
- inversion H0; now subst.
(* case Var *)
- inversion H2; subst.
  assert (Ha : TermV ty = TermV t2).
  erewrite ok_unique_type with (x0 := x).
  reflexivity.
  apply wfenv_to_ok in H4.
  apply H4.
  apply (conj H5 H0).
  decide equality.
  now inversion Ha.
(* case Lit *)
- inversion H0. auto.
(* case App *)
- inversion H1.
  apply IHhas_type_source_alg1 in H5. simpl in H5.
  apply IHhas_type_source_alg2 in H6.
  injection H5. intros. auto.
(* Case Merge *)
- inversion H2.
  apply IHhas_type_source_alg1 in H5.
  apply IHhas_type_source_alg2 in H7.
  rewrite H5. rewrite H7. auto.
(* Case Ann *)
- inversion H0. auto.
(* Case TApp *)
- inversion H2; subst.
  apply IHhas_type_source_alg in H7.
  injection H7; intros.
  now subst.
Qed.

(* Theorem 5. Type inference always gives unique types *)

Lemma typ_inf_unique : forall {Gamma e t1 t2 E1 E2}, has_type_source_alg Gamma e Inf t1 E1 -> has_type_source_alg Gamma e Inf t2 E2 -> t1 = t2.
intros.
pose (@typ_unique _ _ _ _ _ H _ _ H0). simpl in a. auto.
Qed.

(* Theorem 6. *)
Lemma typ_coherence : forall Gamma e d t E1, has_type_source_alg Gamma e d t E1 -> forall E2, has_type_source_alg Gamma e d t E2 -> E1 = E2.
intros Gamma e d t E1 H.
induction H; intros.
(* case Unit *)
- inversion H0; reflexivity.
(* case PFVar *)
- inversion H2; reflexivity. 
(* case STLit *)
- inversion H0; reflexivity.
(* Case App *)
- inversion H1.
  assert (Fun A B = Fun A0 B).
  apply (typ_inf_unique H H5). injection H9. intros.
  rewrite <- H9 in H5. rewrite <- H10 in H6.
  apply IHhas_type_source_alg1 in H5. 
  apply IHhas_type_source_alg2 in H6.
  rewrite H5. rewrite H6. auto.
(* Case Merge *)
- inversion H2.
  apply IHhas_type_source_alg1 in H8.
  apply IHhas_type_source_alg2 in H9.
  rewrite H8. rewrite H9. auto.
(* Case Ann *)
- inversion H0.
  apply IHhas_type_source_alg in H3. auto.
(* Case TApp *)
- inversion H2; subst.
  assert (Ha : ForAll d ty = ForAll d0 ty0).
  eapply typ_inf_unique.
  apply H0.
  apply H8.
  rewrite <- Ha in H8.
  apply IHhas_type_source_alg in H8.
  now subst.
(* Case Lam *)
- inversion H2; subst.
  apply f_equal.
  pick_fresh x.
  assert (Ha1: not (M.In x L0)) by (not_in_L x).
  apply H7 in Ha1.
  apply H0 in Ha1.
  assert (HNotE : not (In x (fv E))) by (not_in_L x).
  assert (HNotF : not (In x (fv E0))) by (not_in_L x).
  apply (open_app_eq _ _ _ _ HNotE HNotF Ha1).
  not_in_L x.
  inversion H3. 
(* ATySub *)
- inversion H2.
  subst.
  inversion H.
  assert (A = A0).
  apply (typ_inf_unique H H3).
  subst.
  apply IHhas_type_source_alg in H3.
  subst.
  assert (WFTyp Gamma A0). now apply typing_wf_source_alg in H.
  assert (WFTyp Gamma B). assumption.
  assert (C = C0).
  apply (sub_coherent H3 H6 H0 H4).
  subst; reflexivity.
  subst; inversion H.
(* Case TLam *)
- inversion H2; subst.
  inversion H3.
  apply f_equal.
  pick_fresh x.
  apply open_typ_term_app_eq with (E := E) (F := E0) (x := x) (n := 0).
  not_in_L x.
  not_in_L x.
  apply H1.
  not_in_L x.
  apply H8.
  not_in_L x.
Qed.

Lemma coercions_produce_terms :
  forall E A B, sub A B E -> STTerm E.
Proof.
  intros.
  induction H.
  (* Case SInt *)
  - apply_fresh STTerm_Lam as x; cbn; auto.
  (* Case SFun *)
  - apply_fresh STTerm_Lam as x; cbn.
    apply_fresh STTerm_Lam as y; cbn.
    apply STTerm_App.
    repeat rewrite <- open_rec_term; assumption.
    apply STTerm_App.
    apply STTerm_Var.
    apply STTerm_App; [ repeat rewrite <- open_rec_term; auto | apply STTerm_Var ].
  (* Case SAnd1 *)
  - apply_fresh STTerm_Lam as x; cbn.
    apply STTerm_Pair.
    apply STTerm_App; repeat rewrite <- open_rec_term; auto.
    rewrite <- open_rec_term; auto.
  (* Case SAnd2 *)
  - apply and_coercion_proj1_term with (t0 := t0) (c := c); auto.
    assert (Ha : Sub t1 t0) by (unfold Sub; eauto).
    now apply sub_lc in Ha as [Ha1 Ha2].
  (* Case SAnd3 *)
  - apply and_coercion_proj2_term with (t0 := t0) (c := c); auto.
    assert (Ha : Sub t2 t0) by (unfold Sub; eauto).
    now apply sub_lc in Ha as [Ha1 Ha2].
  (* Case SVar *)
  - apply_fresh STTerm_Lam as x; cbn; auto.
  (* Case SForAll *)
  - apply_fresh STTerm_Lam as x; cbn.
    apply_fresh STTerm_TLam as y; cbn.
    apply STTerm_App; auto.
    assert (Ha : not (In y L)) by (not_in_L y).
    apply H0 in Ha.
    rewrite open_comm_open_typ_term.
    rewrite <- open_rec_term; auto.
  (* Case STop *)
  - apply_fresh STTerm_Lam as x; cbn; auto.
Qed.

Hint Resolve coercions_produce_terms.


(* Subtyping rules produce type-correct coercions: Lemma 1 *)
Lemma type_correct_coercions :
  forall Gamma A B E, sub A B E ->
             WFEnv Gamma ->
             WFTyp Gamma A ->
             WFTyp Gamma B ->
             has_type_st (∥ Gamma ∥) E (STFun (|A|) (|B|)) .
Proof.
  intros.
  generalize dependent Gamma.
  induction H; intros.
  (* Case SInt *)
  - simpl.
    remember (∥ Gamma ∥).
    apply_fresh STTyLam as x; cbn; auto.
    apply STTyVar; auto.
    apply WFType_Int; auto.
    apply Ok_push; auto.
    subst; auto.
    apply wfenv_to_ok in H0; auto.
    not_in_L x.
    apply Ok_push; auto.
    subst; auto.
    not_in_L x.
    left; simpl; auto.
    apply WFType_Int.
    subst; auto.
  (* Case SFun *)
  - inversion H2; inversion H3.
    subst.
    remember (∥ Gamma ∥).
    apply_fresh STTyLam as x; cbn.
    apply_fresh STTyLam as y; cbn.
    apply STTyApp with (A := (| o2 |)).
    rewrite <- open_rec_term.
    rewrite <- open_rec_term.
    repeat apply typing_weaken_extend.
    subst; apply (IHsub2 _ H1 H8 H13).
    not_in_L x.
    not_in_L y.
    not_in_L x.
    now apply coercions_produce_terms in H0.
    rewrite <- open_rec_term.
    now apply coercions_produce_terms in H0.
    now apply coercions_produce_terms in H0.
    apply STTyApp with (A := (| o1 |)).
    apply STTyVar.
    repeat apply wf_weaken_extend.
    apply WFType_Fun.
    subst; now apply WFTyp_to_WFType.
    subst; now apply WFTyp_to_WFType.
    not_in_L x.
    not_in_L y.
    not_in_L x.
    apply Ok_push.
    apply Ok_push.
    subst; auto.
    not_in_L x.
    not_in_L y.
    not_in_L x.
    right; left; auto.
    rewrite <- open_rec_term.
    rewrite <- open_rec_term.
    eapply STTyApp.
    repeat apply typing_weaken_extend.
    subst; apply IHsub1; auto.
    not_in_L x.
    not_in_L y.
    not_in_L x.
    apply STTyVar.
    repeat apply wf_weaken_extend.
    inversion H3.
    subst; now apply WFTyp_to_WFType.
    not_in_L x.
    not_in_L y.
    not_in_L x.
    apply Ok_push.
    apply Ok_push.
    subst; auto.
    not_in_L x.
    not_in_L y.
    not_in_L x.
    left; auto.    
    now apply coercions_produce_terms in H.
    rewrite <- open_rec_term.
    now apply coercions_produce_terms in H.
    now apply coercions_produce_terms in H.
    apply wf_weaken_extend.
    subst; now apply WFTyp_to_WFType.
    not_in_L x.
    apply WFType_Fun; subst; now apply WFTyp_to_WFType.
  (* Case SAnd1 *)
  - remember (∥ Gamma ∥).
    inversion H3.
    apply_fresh STTyLam as x; cbn.
    apply STTyPair.
    + rewrite <- open_rec_term.
      apply STTyApp with (A := (| t0 |)).
      apply typing_weaken_extend.
      subst; apply IHsub1; auto.
      not_in_L x.
      apply STTyVar.
      apply wf_weaken_extend.
      subst; now apply WFTyp_to_WFType.
      not_in_L x.
      apply Ok_push.
      subst; auto.
      not_in_L x.
      left; auto.
      now apply coercions_produce_terms in H.
    + rewrite <- open_rec_term.
      apply STTyApp with (A := (| t0 |)).
      apply typing_weaken_extend.
      subst; apply IHsub2; auto.
      not_in_L x.
      apply STTyVar.
      apply wf_weaken_extend.
      subst; now apply WFTyp_to_WFType.
      not_in_L x.
      apply Ok_push.
      subst; auto.
      not_in_L x.
      left; auto.
      now apply coercions_produce_terms in H0.
    + subst; now apply WFTyp_to_WFType.
  (* Case SAnd2 *)
  - assert (Ha1 : Sub t1 t0) by (unfold Sub; eauto).
    assert (Ha : PType t0) by (apply sub_lc in Ha1; now destruct Ha1).
    pose (toplike_dec t0 Ha).
    inversion o; clear o.
    change (STFun (| And t1 t2 |) (| t0 |)) with
    (| Fun (And t1 t2) t0 |).
    eapply and_coercion_inl_typing; auto.
    apply ACFunL.
    eapply and_coercion_inl in H6.
    destruct H6.
    assert (Ha2 : ac = inl x).
    eapply same_coercion with (A := t0); auto.
    apply H2. apply H6.
    subst.
    unfold join_sum; simpl.
    apply H6.
    auto.
    apply_fresh STTyLam as x.
    apply and_coercion_inr with (e := (STApp var c (STProj1 var (STBVar var 0)))) in H6.
    assert (Ha2 : ac = (inr (STApp var c (STProj1 var (STBVar var 0))))).
    eapply same_coercion with (A := t0); auto.
    apply H2. apply H6. subst.
    unfold join_sum, open; simpl.
    rewrite <- open_rec_term.
    eapply STTyApp.
    change (extend x (TermVar STyp (STTuple (| t1 |) (| t2 |))) (∥ Gamma ∥)) with
    (∥ extend x (TermV (And t1 t2)) Gamma ∥).    
    apply IHsub.
    apply WFPushT; auto; not_in_L x.
    admit. (* change lemmas with WFEnv and add them to env_resolve *)
    admit. (* same *)
    eapply STTyProj1.
    apply STTyVar.
    admit. (* same *)
    apply Ok_push.
    env_resolve.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    left; reflexivity.
    now apply coercions_produce_terms in H.
    auto.
    auto.
  (* Case SAnd3 *)
  - admit.
    (* assert (Ha1 : Sub t2 t0) by (unfold Sub; eauto).
    assert (Ha : PType t0) by (apply sub_lc in Ha1; now destruct Ha1).
    pose (toplike_dec t0 Ha).
    inversion o; clear o.
    assert (Ha2 : exists r, and_coercion' t0 (STApp _ c (STProj2 _ (STBVar _ 0))) = inl r /\ has_type_st (∥ Gamma ∥) r (|t0|)) by (apply and_coercion_inl_typing; auto).
    destruct Ha2 as [r [HCoerce HHasTy]].
    apply_fresh STTyLam as x.
    simpl; unfold open; rewrite <- open_rec_term.
    rewrite <- app_nil_l with (l := (extend x (TermVar STyp (STTuple (| t1 |) (| t2 |))) (∥ Gamma ∥))).
    apply typing_weaken; rewrite app_nil_l.
    now rewrite HCoerce; simpl.
    apply Ok_push; auto.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    rewrite HCoerce; simpl.
    now apply typing_gives_terms in HHasTy.
    env_resolve.
    eapply and_coercion_inr in H5.
    rewrite H5; simpl.
    apply_fresh STTyLam as x; cbn.
    eapply STTyApp.
    rewrite <- open_rec_term.
    apply typing_weaken_extend.
    apply IHsub.
    assumption.
    now inversion H3.
    assumption.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    now apply coercions_produce_terms in H.
    eapply STTyProj2.
    apply STTyVar.
    apply wf_weaken_extend.
    Focus 4.
    left; reflexivity.
    change (STTuple (| t1 |) (| t2 |)) with (| And t1 t2 |).
    env_resolve.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    apply Ok_push; auto.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    change (STTuple (| t1 |) (| t2 |)) with (| And t1 t2 |).
    env_resolve.
    auto. *)
  - remember (∥ Gamma ∥).
    apply_fresh STTyLam as x.
    unfold open; simpl.
    apply STTyVar.
    apply wf_weaken_extend.
    subst; now apply WFTyp_to_WFType in H1.
    not_in_L x.
    apply Ok_push.
    subst; auto.
    not_in_L x.
    left; auto.
    subst; now apply WFTyp_to_WFType in H1.
  (* ForAll *)
  - inversion H3.
    inversion H4.
    apply_fresh STTyLam as x.
    unfold open; simpl.
    apply_fresh STTyTLam as y.
    unfold open_typ_term; simpl.
    apply STTyApp with (A := (open_typ (| t1 |) (STFVarT y))).
    rewrite open_comm_open_typ_term.
    rewrite <- open_rec_term.
    unfold open_typ; simpl.
    unfold open_typ_source in H0; simpl in H0.
    change (extend y (TyVar STyp)
                   (extend x (TermVar STyp (STForAll (| t1 |))) (∥ Gamma ∥))) with
    (∥ (extend y (TyDis d)
               (extend x (TermV (ForAll d t1)) Gamma)) ∥).
    change (STFVarT y) with (| PFVarT y |).
    rewrite <- open_rec_typ_eq_source.
    rewrite <- open_rec_typ_eq_source.
    apply H0.
    not_in_L y.
    apply WFPushV.
    apply WFPushT.
    auto.
    not_in_L x.
    not_in_L y.
    simpl.
    unfold not; intro HH.
    apply MSetProperties.Dec.F.add_iff in HH.
    destruct HH; subst.
    not_in_L y.
    exfalso; apply H25; now apply MSetProperties.Dec.F.singleton_2.
    not_in_L y.
    unfold extend.
    apply wf_weaken_source.
    subst.
    apply H8.
    not_in_L y.
    apply WFPushV.
    apply WFPushT.
    auto.
    not_in_L x.
    not_in_L y.
    simpl.
    unfold not; intro HH.
    apply MSetProperties.Dec.F.add_iff in HH.
    destruct HH; subst.
    not_in_L y.
    exfalso; apply H25; now apply MSetProperties.Dec.F.singleton_2.
    not_in_L y.
    apply wf_weaken_source.
    subst.
    apply H13.
    not_in_L y.
    apply WFPushV.
    apply WFPushT.
    auto.
    not_in_L x.
    not_in_L y.
    not_in_L y.
    not_in_L x.
    assert (Ha : not (In y L)) by not_in_L y.
    apply H in Ha.
    now apply coercions_produce_terms in Ha.
    apply STTyTApp.
    apply WFType_Var.
    apply Ok_push.
    apply Ok_push.
    subst; auto.
    unfold conv_context; rewrite <- dom_map_id.
    not_in_L x.
    unfold extend; not_in_L y.
    not_in_L x.
    subst; unfold conv_context in H17; rewrite <- dom_map_id in H17; contradiction.
    left; auto.
    apply STTyVar.
    repeat apply wf_weaken_extend.
    change (STForAll (| t1 |)) with (| ForAll d t1 |).
    env_resolve.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    unfold extend; not_in_L y.
    not_in_L x.
    subst; unfold conv_context in H17; rewrite <- dom_map_id in H17; contradiction.
    apply Ok_push.
    apply Ok_push.
    subst; auto.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    unfold extend; not_in_L y.
    not_in_L x.
    subst; unfold conv_context in H17; rewrite <- dom_map_id in H17; contradiction.
    right; left; auto.
    subst.
    env_resolve.
  - apply_fresh STTyLam as x.
    unfold open; simpl.
    apply STTyUnit.
    apply Ok_push.
    env_resolve.
    unfold conv_context; rewrite <- dom_map_id; not_in_L x.
    env_resolve.
Qed.
  
(* Type preservation: Theorem 1 *)
Lemma type_preservation :
  forall x ty dir E (Gamma : context TyEnvSource) (H : has_type_source_alg Gamma x dir ty E),
  has_type_st (∥ Gamma ∥) E (|ty|).
Proof.
  intros.
  induction H; subst; auto.
  (* TyVar *)
  - apply STTyVar.
    now apply WFTyp_to_WFType.
    auto.
    now apply in_persists in H0.
  (* TyApp *)
  - simpl in *.
    apply STTyApp with (A := |A|).
    assumption.
    assumption.
  (* TyMerge *)
  - simpl; apply STTyPair; assumption.
  (* TyTApp *)
  - simpl in *.
    unfold open_typ_source; rewrite open_rec_typ_eq_source.
    apply STTyTApp.
    now apply WFTyp_to_WFType.
    apply IHhas_type_source_alg.
  (* TyLam *)
  - simpl.
    apply_fresh STTyLam as x.
    unfold open; simpl.
    assert (Ha : not (M.In x L)).
    not_in_L x.
    apply H0 in Ha.
    simpl in *.
    unfold extend.
    simpl.
    apply Ha.
    now apply WFTyp_to_WFType.
  (* ATySub *)
  - apply STTyApp with (|A|).
    apply type_correct_coercions.
    assumption.
    now apply typing_alg_wf_env in H.
    now apply typing_wf_source_alg in H.
    assumption.
    assumption.
  (* ATyTLam *)
  - simpl; apply_fresh STTyTLam as x.
    simpl in *.
    unfold open_typ.
    change (STFVarT x) with (| PFVarT x |).
    rewrite <- open_rec_typ_eq_source.
    apply H1.
    not_in_L x.
Qed.

End Extended.