# a clean mapping passes every check and returns the crosswalk invisibly

    Code
      out <- run_check()
    Message
      v No duplicate taxonomy leaves.
      v Every crosswalk row sits on a taxonomy leaf.
      v Every variable is in the cliaretl catalogue.
      v Every variable has CTF values in at least one panel.

# duplicate taxonomy leaves stop the build

    Code
      run_check(taxonomy = tax)
    Condition
      Error in `check_cgjr_mapping()`:
      x Duplicate taxonomy leaves:
      i "budget"

# crosswalk rows off the taxonomy stop the build and are named

    Code
      run_check(crosswalk = xw)
    Message
      v No duplicate taxonomy leaves.
    Condition
      Error in `check_cgjr_mapping()`:
      x Crosswalk rows whose leaf is not in the taxonomy:
      i "Courts (env > justise)"

# duplicate observations stop the build and name the repeated keys

    Code
      check_duplicate_obs(dup, obs_keys)
    Condition
      Error in `check_duplicate_obs()`:
      x Duplicate observations on ctf_type / unit_code / year / variable:
      i "dynamic / GHA / 2020 / v_corr"

