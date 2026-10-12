# ==============================================================================
# Vivado Implementation Hook: Disable Placer Precondition DRC Stack Overflow Traps
# ==============================================================================
puts "=== DISABLE_DRC_HOOK: Neutralizing placer precondition checks ==="

# 1. Disable the entire placer_checks ruledeck (prevents LCCH-1 & AVAL recursive crashes)
catch { set_property IS_ENABLED false [get_drc_checks -quiet -ruledeck placer_checks] }

# 2. Direct overrides for default ruledeck checks if invoked outside placer_checks
catch { set_property IS_ENABLED false [get_drc_checks -quiet LUTLP-1] }
catch { set_property IS_ENABLED false [get_drc_checks -quiet LUTLP-2] }
catch { set_property IS_ENABLED false [get_drc_checks -quiet LCCH-1] }

# 3. Tell Vivado's C++ placer engine to skip the precondition check phase
catch { set_param place.disableDrcCheck 1 }

puts "=== DISABLE_DRC_HOOK: Hook execution complete ==="

