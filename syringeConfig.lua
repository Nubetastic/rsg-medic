SyringeConfig = {
    -- Inventory item used to perform a syringe revive
    ItemName = 'syringe',

    -- World prop attached during the animation (adjust if your model differs)
    PropName = 'p_syringe01x',

    -- Timing
    ReviveTime = 5000,       -- milliseconds the revive takes (also used for progress notify)
    CooldownTime = 30,       -- seconds before syringe can be used again
    ReviveDistance = 2.0,    -- max distance for ox_target interaction

    -- Animations (male/female). Use valid RedM anim dicts/names
    AnimDict = 'mech_revive@unapproved',
    AnimName = 'syringe_revive',
    AnimDictFemale = 'mech_revive@unapproved',
    AnimNameFemale = 'syringe_revive',

    -- Notification text
    Notifications = {
        CooldownActive = 'Syringe is on cooldown',
        ReviveInProgress = 'Reviving with syringe...',
        ReviveFailed = 'Revive failed',
        ReviveComplete = 'You have been revived',
    }
}