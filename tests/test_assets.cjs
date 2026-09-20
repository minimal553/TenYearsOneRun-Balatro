const fs=require('fs');
const path=require('path');
const assert=require('assert');
const sharp=require(process.env.TYG_NODE_MODULES?path.join(process.env.TYG_NODE_MODULES,'sharp'):'sharp');
const root=process.env.TYG_TEST_MOD_DIR||path.resolve(__dirname,'../mod/TenYearsNineGrid');
(async()=>{
 for(const scale of [1,2])for(const name of ['deck','fortune','natal','patterns','legacy_booster']){
  const file=path.join(root,'assets',`${scale}x`,name+'.png');
  assert(fs.existsSync(file),'real custom game artwork missing: '+file);
  const info=await sharp(file).metadata();
  assert.equal(info.width,71*scale*(['natal','patterns'].includes(name)?5:1));assert.equal(info.height,95*scale*(name==='patterns'?6:1));
  assert(info.hasAlpha,'sprite must retain transparency');
  const {data,info:raw}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  for(let cell=0;cell<(name==='patterns'?26:name==='natal'?5:1);cell++){
   const x=(cell%5)*71*scale, y=Math.floor(cell/5)*95*scale;
   assert.equal(data[(y*raw.width+x)*4+3],0,'each sprite top-left corner transparent');
   const center=x+Math.floor(71*scale/2),mid=y+Math.floor(95*scale/2);
   assert(data[((mid*raw.width+center)*4)+3]>0,'focal center visible: '+name+' cell'+cell);
  }
 }
 console.log('PASS 10 runtime PNGs including all26 pattern cells: dimensions, alpha, visible centers');
})().catch(e=>{console.error(e);process.exitCode=1;});
