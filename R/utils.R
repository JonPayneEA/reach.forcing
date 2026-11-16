# ============================================================
# Tool:         utils
# Description:  Internal checks shared by the package's functions
# Flode Module: reach.forcing
# Author:       reach.forcing contributors
# Created:      2026-11-16
# Tier:         1
# Inputs:       none
# Outputs:      none
# Dependencies: none
# ============================================================

# Stops with a plain message, without the call, when a condition fails.
.check <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)

# TRUE for one finite number, at least lower (strictly above it when strict).
.scalar <- function(x, lower = -Inf, strict = FALSE) {
  is.numeric(x) && length(x) == 1L && is.finite(x) && (if (strict) x > lower else x >= lower)
}
