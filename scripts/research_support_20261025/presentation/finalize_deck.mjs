import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const ROOT='C:/Users/lenovo/Desktop/Research/Impact-melt-migration';
const B=ROOT+'/tmp/research_ppt_build_20261025';
const S='C:/Users/lenovo/.codex/plugins/cache/openai-primary-runtime/presentations/26.1020.11127/skills/presentations';
process.env.RUNTIME_NODE_MODULES='C:/Users/lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
process.env.RUNTIME_NODE=process.execPath;
const {finalizePresentation}=await import(pathToFileURL(S+'/container_tools/artifact_tool_utils.mjs'));
const req=JSON.parse(await fs.readFile(B+'/requirements.json','utf8'));
const preflight=process.argv.includes('--preflight');
const candidate=preflight?B+'/candidate_base.pptx':B+'/candidate_media_clean.pptx';
const finalPath=preflight?B+'/preflight_output/preflight.pptx':ROOT+'/Output/research_presentation_20261025/Melt_migration_tests_and_mechanisms.pptx';
await fs.mkdir(path.dirname(finalPath),{recursive:true});
const result=await finalizePresentation({
 workspaceDir:ROOT,candidatePath:candidate,finalPath,
 pythonExecutable:'C:/Users/lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
 integrityValidatorPath:S+'/container_tools/inspect_presentation_package_integrity.py',
 layoutValidatorPath:S+'/container_tools/inspect_presentation_layout_geometry.py',
 layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',
  ...req.requiredNativeTableOwnerSlides.flatMap(n=>['--require-native-table-slide',String(n)])],
 requiredNativeTableOwnerSlides:req.requiredNativeTableOwnerSlides,
 requiredNativeChartOwnerSlides:req.requiredNativeChartOwnerSlides,
 explicitTotalSlideCount:27,fontPolicy:req.fontPolicy,
 materializeLiteralChartWorkbooks:true,nativeChartTargetApplication:'powerpoint',verifyArtifactToolImport:true,
 receiptPath:B+(preflight?'/preflight.validation.json':'/final.validation.json')
});
console.log(JSON.stringify(result));
