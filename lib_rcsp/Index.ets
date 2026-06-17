/**
 * Re-export Jieli vendor HARs.
 * Copy the three .har files from HarmonyOS-JL_OTA into lib_rcsp/lib/ before building:
 *   - JL_OTA_1.0.1-release.har
 *   - JL_RCSP_1.0.1-release.har
 *   - JL_Auth_1.0.1-release.har
 */
import * as JL_OTA from 'jl-ota';
import * as JL_RCSP from 'jl-rcsp';
import * as JLAuth from 'jl-auth';

export {
  JL_OTA,
  JL_RCSP,
  JLAuth
};
