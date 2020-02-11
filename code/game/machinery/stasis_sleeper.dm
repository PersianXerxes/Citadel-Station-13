#define STASIS_TOGGLE_COOLDOWN 50

/obj/machinery/stasis_sleeper
	name = "stasis sleeper"
	desc = "A not so comfortable looking bed with nozzles at its head and foot, enclosed within a machine used to stabilize and heal patients."
	icon = 'icons/obj/machines/sleeper.dmi'
	icon_state = "sleeper"
	density = FALSE
	state_open = TRUE
	circuit = /obj/item/circuitboard/machine/stasis_sleeper
	idle_power_usage = 40
    active_power_usage = 340
    req_access = list(ACCESS_CMO) //Used for reagent deletion and addition of non medicines
	var/stasis_enabled = TRUE
    var/last_stasis_sound = FALSE
    var/stasis_can_toggle = 0
    var/mattress_state = "stasis_on"
    var/efficiency = 1
	var/min_health = 30
	var/list/available_chems
	var/controls_inside = FALSE
	var/list/possible_chems = list(
		list(/datum/reagent/medicine/epinephrine, /datum/reagent/medicine/morphine, /datum/reagent/medicine/salbutamol, /datum/reagent/medicine/bicaridine, /datum/reagent/medicine/kelotane),
		list(/datum/reagent/medicine/oculine,/datum/reagent/medicine/inacusiate),
		list(/datum/reagent/medicine/antitoxin, /datum/reagent/medicine/mutadone, /datum/reagent/medicine/mannitol, /datum/reagent/medicine/pen_acid),
		list(/datum/reagent/medicine/omnizine)
	)
	var/list/chem_buttons	//Used when emagged to scramble which chem is used, eg: antitoxin -> morphine
	var/scrambled_chems = FALSE //Are chem buttons scrambled? used as a warning
	var/enter_message = "<span class='notice'><b>You feel cool air surround you. You go numb as your senses turn inward.</b></span>"

/obj/machinery/stasis_sleeper/Initialize()
	. = ..()
	create_reagents(500, NO_REACT)
	occupant_typecache = GLOB.typecache_living
	update_icon()
	reset_chem_buttons()
	RefreshParts()
	add_inital_chems()

/obj/machinery/stasis_sleeper/proc/stasis_running()
    return stasis_enabled && is_operational()

/obj/machinery/stasis_sleeper/obj_break(damage_flag)
    . = ..()
    play_power_sound()
    update_icon()

/obj/machinery/stasis_sleeper/power_change()
    . = ..()
    player_power_sound()
    update_icon()

/obj/machinery/stasis_sleeper/on_deconstruction()
	var/obj/item/reagent_containers/sleeper_buffer/buffer = new (loc)
	buffer.volume = reagents.maximum_volume
	buffer.reagents.maximum_volume = reagents.maximum_volume
	reagents.trans_to(buffer.reagents, reagents.total_volume)

/obj/machinery/stasis_sleeper/proc/add_inital_chems()
	for(var/i in available_chems)
		var/datum/reagent/R = reagents.has_reagent(i)
		if(!R)
			reagents.add_reagent(i, (20))
			continue
		if(R.volume < 20)
			reagents.add_reagent(i, (20 - R.volume))

/obj/machinery/stasis_sleeper/RefreshParts()
	var/E
	for(var/obj/item/stock_parts/matter_bin/B in component_parts)
		E += B.rating
	var/I
	for(var/obj/item/stock_parts/manipulator/M in component_parts)
		I += M.rating

	efficiency = initial(efficiency)* E
	min_health = initial(min_health) - (10*(E-1)) // CIT CHANGE - changes min health equation to be min_health - (matterbin rating * 10)
	available_chems = list()
	for(var/i in 1 to I)
		available_chems |= possible_chems[i]
	reset_chem_buttons()

	//Total container size 500 - 2000u
	if(reagents)
		reagents.maximum_volume = (500*E)

/obj/machinery/stasis_sleeper/proc/play_power_sound()
    var/_running = stasis_running()
    if(last_stasis_sound != _running)
        var/sound_freq = rand(5120, 8800)
        if(_running)
            playsound(src, 'sound/machines/synth_yes.ogg', 50, TRUE, frequency = sound_freq)
        else
            playsound(src, 'sound/machines/synth_no.ogg', 50, TRUE, frequency = sound_freq)
        last_stasis_sound = _running

/obj/machinery/stasis_sleeper/update_icon()
	icon_state = initial(icon_state)
	if(state_open)
		icon_state += "-open"

/obj/machinery/stasis_sleeper/container_resist(mob/living/AM)
	if(AM == occupant)
		var/mob/living/L = AM
		if(L.IsInStasis())
			thaw_them(L)
    . = ..()
    visible_message("<span class='notice'>[occupant] emerges from [src]!</span>",
		"<span class='notice'>You climb out of [src]!</span>")
	open_machine()

/obj/machinery/stasis_sleeper/Exited(atom/movable/AM, atom/newloc)
	if (!state_open && AM == occupant)
		container_resist(user)

/obj/machinery/stasis_sleeper/relaymove(mob/user)
	if (!state_open)
		container_resist(user)

/obj/machinery/stasis_sleeper/open_machine()
	if(!state_open && !panel_open)
		..()

/obj/machinery/stasis_sleeper/close_machine(mob/user)
	if((isnull(user) || istype(user)) && state_open && !panel_open)
		..(user)
		var/mob/living/mob_occupant = occupant
		if(mob_occupant && mob_occupant.stat != DEAD)
			to_chat(occupant, "[enter_message]")

/obj/machinery/stasis_sleeper/emp_act(severity)
	. = ..()
	if (. & EMP_PROTECT_SELF)
		return
	if(is_operational() && occupant)
		var/datum/reagent/R = pick(reagents.reagent_list)
		inject_chem(R.type, occupant)
		open_machine()
	//Is this too much?
	if(severity == EMP_HEAVY)
		var/chem = pick(available_chems)
		available_chems -= chem
		available_chems += get_random_reagent_id()
		reset_chem_buttons()

/obj/machinery/stasis_sleeper/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/reagent_containers/sleeper_buffer))
		var/obj/item/reagent_containers/sleeper_buffer/SB = I
		if((SB.reagents.total_volume + reagents.total_volume) < reagents.maximum_volume)
			SB.reagents.trans_to(reagents, SB.reagents.total_volume)
			visible_message("[user] places the [SB] into the [src].")
			qdel(SB)
			return
		else
			SB.reagents.trans_to(reagents, SB.reagents.total_volume)
			visible_message("[user] adds as much as they can to the [src] from the [SB].")
			return
	if(istype(I, /obj/item/reagent_containers))
		var/obj/item/reagent_containers/RC = I
		if(RC.reagents.total_volume == 0)
			to_chat(user, "<span class='notice'>The [I] is empty!</span>")
		for(var/datum/reagent/R in RC.reagents.reagent_list)
			if((obj_flags & EMAGGED) || (allowed(usr)))
				break
			if(!istype(R, /datum/reagent/medicine))
				visible_message("The [src] gives out a hearty boop and rejects the [I]. The Sleeper's screen flashes with a pompous \"Medicines only, please.\"")
				return
		RC.reagents.trans_to(reagents, 1000)
		visible_message("[user] adds as much as they can to the [src] from the [I].")
		return

/obj/machinery/stasis_sleeper/MouseDrop_T(mob/target, mob/user)
	if(user.stat || user.lying || !Adjacent(user) || !user.Adjacent(target) || !iscarbon(target) || !user.IsAdvancedToolUser())
		return
	close_machine(target)

/obj/machinery/stasis_sleeper/screwdriver_act(mob/living/user, obj/item/I)
	. = TRUE
	if(..())
		return
	if(occupant)
		to_chat(user, "<span class='warning'>[src] is currently occupied!</span>")
		return
	if(state_open)
		to_chat(user, "<span class='warning'>[src] must be closed to [panel_open ? "close" : "open"] its maintenance hatch!</span>")
		return
	if(default_deconstruction_screwdriver(user, "[initial(icon_state)]-o", initial(icon_state), I))
		return
	return FALSE

/obj/machinery/stasis_sleeper/wrench_act(mob/living/user, obj/item/I)
	. = ..()
	if(default_change_direction_wrench(user, I))
		return TRUE

/obj/machinery/stasis_sleeper/crowbar_act(mob/living/user, obj/item/I)
	. = ..()
	if(default_pry_open(I))
		return TRUE
	if(default_deconstruction_crowbar(I))
		return TRUE

/obj/machinery/stasis_sleeper/default_pry_open(obj/item/I) //wew
	. = !(state_open || panel_open || (flags_1 & NODECONSTRUCT_1)) && I.tool_behaviour == TOOL_CROWBAR
	if(.)
		I.play_tool_sound(src, 50)
		visible_message("<span class='notice'>[usr] pries open [src].</span>", "<span class='notice'>You pry open [src].</span>")
		open_machine()

/obj/machinery/stasis_sleeper/AltClick(mob/user)
	. = ..()
	if(!user.canUseTopic(src, !hasSiliconAccessInArea(user)))
		return
	if(state_open)
		close_machine()
	else
		open_machine()
	return TRUE

/obj/machinery/stasis_sleeper/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Alt-click [src] to [state_open ? "close" : "open"] it.</span>"

/obj/machinery/stasis_sleeper/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, \
									datum/tgui/master_ui = null, datum/ui_state/state = GLOB.notcontained_state)

	if(controls_inside && state == GLOB.notcontained_state)
		state = GLOB.default_state // If it has a set of controls on the inside, make it actually controllable by the mob in it.

	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "sleeper", name, 550, 700, master_ui, state)
		ui.open()

/obj/machinery/stasis_sleeper/proc/chill_out(mob/living/target)
	if(target != occupant)
		return
	var/freq = rand(24750, 26550)
	playsound(src, 'sound/effects/spray.ogg', 5, TRUE, 2, frequency = freq)
	target.SetStasis(TRUE)
	target.ExtinguishMob()
	use_power = ACTIVE_POWER_USE

/obj/machinery/stasis_sleeper/proc/thaw_them(mob/living/target)
	target.SetStasis(FALSE)
	if(target == occupant)
		use_power = IDLE_POWER_USE

/obj/machinery/stasis_sleeper/process()
	if( !( occupant && isliving(occupant)) )
		use_power = IDLE_POWER_USE
		return
	var/mob/living/L_occupant = occupant
	if(stasis_running())
		if(!L_occupant.IsInStasis())
			chill_out(L_occupant)
	else if(L_occupant.IsInStasis())
		thaw_them(L_occupant)

/obj/machinery/stasis_sleeper/ui_data()
	var/list/data = list()
	data["occupied"] = occupant ? 1 : 0
	data["open"] = state_open
    data["stasis"] = stasis_enabled
	data["efficiency"] = efficiency
	data["current_vol"] = reagents.total_volume
	data["tot_capacity"] = reagents.maximum_volume

	data["chems"] = list()
	for(var/chem in available_chems)
		var/datum/reagent/R = reagents.has_reagent(chem)
		R = GLOB.chemical_reagents_list[chem]
		data["synthchems"] += list(list("name" = R.name, "id" = R.type, "synth_allowed" = synth_allowed(chem)))
	for(var/datum/reagent/R in reagents.reagent_list)
		data["chems"] += list(list("name" = R.name, "id" = R.type, "vol" = R.volume, "purity" = R.purity, "allowed" = chem_allowed(R.type)))

	data["occupant"] = list()
	var/mob/living/mob_occupant = occupant
	if(mob_occupant)
		data["occupant"]["name"] = mob_occupant.name
		switch(mob_occupant.stat)
			if(CONSCIOUS)
				data["occupant"]["stat"] = "Conscious"
				data["occupant"]["statstate"] = "good"
			if(SOFT_CRIT)
				data["occupant"]["stat"] = "Conscious"
				data["occupant"]["statstate"] = "average"
			if(UNCONSCIOUS)
				data["occupant"]["stat"] = "Unconscious"
				data["occupant"]["statstate"] = "average"
			if(DEAD)
				data["occupant"]["stat"] = "Dead"
				data["occupant"]["statstate"] = "bad"
		data["occupant"]["health"] = mob_occupant.health
		data["occupant"]["maxHealth"] = mob_occupant.maxHealth
		data["occupant"]["minHealth"] = HEALTH_THRESHOLD_DEAD
		data["occupant"]["bruteLoss"] = mob_occupant.getBruteLoss()
		data["occupant"]["oxyLoss"] = mob_occupant.getOxyLoss()
		data["occupant"]["toxLoss"] = mob_occupant.getToxLoss()
		data["occupant"]["fireLoss"] = mob_occupant.getFireLoss()
		data["occupant"]["cloneLoss"] = mob_occupant.getCloneLoss()
		data["occupant"]["brainLoss"] = mob_occupant.getOrganLoss(ORGAN_SLOT_BRAIN)
		data["occupant"]["reagents"] = list()
		if(mob_occupant.reagents && mob_occupant.reagents.reagent_list.len)
			for(var/datum/reagent/R in mob_occupant.reagents.reagent_list)
				data["occupant"]["reagents"] += list(list("name" = R.name, "volume" = R.volume))
		data["occupant"]["failing_organs"] = list()
		var/mob/living/carbon/C = mob_occupant
		if(C)
			for(var/obj/item/organ/Or in C.getFailingOrgans())
				if(istype(Or, /obj/item/organ/brain))
					continue
				data["occupant"]["failing_organs"] += list(list("name" = Or.name))

		if(mob_occupant.has_dna()) // Blood-stuff is mostly a copy-paste from the healthscanner.
			var/blood_id = C.get_blood_id()
			if(blood_id)
				data["occupant"]["blood"] = list() // We can start populating this list.
				var/blood_type = C.dna.blood_type
				if(blood_id != "blood") // special blood substance
					var/datum/reagent/R = GLOB.chemical_reagents_list[blood_id]
					if(R)
						blood_type = R.name
					else
						blood_type = blood_id
				data["occupant"]["blood"]["maxBloodVolume"] = (BLOOD_VOLUME_NORMAL*C.blood_ratio)
				data["occupant"]["blood"]["currentBloodVolume"] = C.blood_volume
				data["occupant"]["blood"]["dangerBloodVolume"] = BLOOD_VOLUME_SAFE
				data["occupant"]["blood"]["bloodType"] = blood_type
	return data

/obj/machinery/stasis_sleeper/ui_act(action, params)
	if(..())
		return
	var/mob/living/mob_occupant = occupant

	switch(action)
		if("door")
			if(state_open)
				close_machine()
			else
				open_machine()
			. = TRUE
		if("inject")
			var/chem = text2path(params["chem"])
			var/amount = text2num(params["volume"])
			if(!is_operational() || !mob_occupant || isnull(chem))
				return
			if(mob_occupant.health < min_health && chem != /datum/reagent/medicine/epinephrine)
				return
			if(inject_chem(chem, usr, amount))
				. = TRUE
				if(scrambled_chems && prob(5))
					to_chat(usr, "<span class='warning'>Chemical system re-route detected, results may not be as expected!</span>")
		if("synth")
			var/chem = text2path(params["chem"])
			if(!is_operational())
				return
			reagents.add_reagent(chem_buttons[chem], 10) //other_purity = 0.75 for when the mechanics are in
		if("purge")
			var/chem = text2path(params["chem"])
			if(allowed(usr))
				if(!is_operational())
					return
				reagents.remove_reagent(chem, 10)
				return
			if(chem in available_chems)
				if(!is_operational())
					return
				/*var/datum/reagent/R = reagents.has_reagent(chem) //For when purity effects are in
				if(R.purity < 0.8)*/
				reagents.remove_reagent(chem, 10)
			else
				visible_message("<span class='warning'>Access Denied.</span>")
				playsound(src, 'sound/machines/terminal_prompt_deny.ogg', 50, 0)


/obj/machinery/stasis_sleeper/emag_act(mob/user)
	. = ..()
	obj_flags |= EMAGGED
	scramble_chem_buttons()
	to_chat(user, "<span class='warning'>You scramble the sleeper's user interface!</span>")
	return TRUE

//trans to
/obj/machinery/stasis_sleeper/proc/inject_chem(chem, mob/user, volume = 10)
	if(chem_allowed(chem))
		reagents.trans_id_to(occupant, chem, volume)//emag effect kicks in here so that the "intended" chem is used for all checks, for extra FUUU
		if(user)
			log_combat(user, occupant, "injected [chem] into", addition = "via [src]")
		return TRUE

/obj/machinery/stasis_sleeper/proc/chem_allowed(chem)
	var/mob/living/mob_occupant = occupant
	if(!mob_occupant || !mob_occupant.reagents)
		return
	var/amount = mob_occupant.reagents.get_reagent_amount(chem) + 10 <= 20 * efficiency
	var/occ_health = mob_occupant.health > min_health || chem == /datum/reagent/medicine/epinephrine
	return amount && occ_health

/obj/machinery/stasis_sleeper/proc/synth_allowed(chem)
	var/datum/reagent/R = reagents.has_reagent(chem)
	if(!R)
		return TRUE
	if(R.volume < 50)
		return TRUE
	return FALSE

/obj/machinery/stasis_sleeper/proc/reset_chem_buttons()
	scrambled_chems = FALSE
	LAZYINITLIST(chem_buttons)
	for(var/chem in available_chems)
		chem_buttons[chem] = chem

/obj/machinery/stasis_sleeper/proc/scramble_chem_buttons()
	scrambled_chems = TRUE
	var/list/av_chem = available_chems.Copy()
	for(var/chem in av_chem)
		chem_buttons[chem] = pick_n_take(av_chem) //no dupes, allow for random buttons to still be correct

#undef STASIS_TOGGLE_COOLDOWN
