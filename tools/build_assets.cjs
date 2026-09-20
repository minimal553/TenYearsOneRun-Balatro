// Mechanical sprite export only. Artwork is sourced from built-in ImageGen.
const fs=require('fs');
const path=require('path');
const sharp=require(process.env.TYG_NODE_MODULES?path.join(process.env.TYG_NODE_MODULES,'sharp'):'sharp');
const root=path.resolve(__dirname,'..');
const source=path.join(root,'assets/concept');
const final=path.join(root,'assets/final/sources');
const out=path.join(root,'mod/TenYearsNineGrid/assets');
const input={deck:'mingju-deck-back-v1.png',fortune:'fortune-v2.png',legacy_booster:'legacy-booster-v1.png',
 bijie:'bijie-v1.png',guanyin:'guanyin-v1.png',shishang:'shishang-v1.png',caixing:'caixing-v1.png',shayin:'shayin-v2.png'};
const patternOrder=['zhengguan','qisha','zhengcai','piancai','zhengyin','pianyin','shishen','shangguan','jianlu','yuejie','yangren','cong_cai','cong_sha','cong_er','cong_shi','quzhi','yanshang','jiase','congge','runxia','hua_tu','hua_jin','hua_shui','hua_mu','hua_huo','changgui'];
const reuse={qisha:'shayin-v2.png',zhengyin:'guanyin-v1.png',shishen:'shishang-v1.png',yuejie:'bijie-v1.png',cong_cai:'caixing-v1.png'};
for(const key of patternOrder)input['mp_'+key]=reuse[key]||('mp_'+key+'-v1.png');
async function card(file){
 const {data}=await sharp(file).resize(71,95,{fit:'contain',kernel:'nearest',background:{r:0,g:0,b:0,alpha:0}})
  .ensureAlpha().raw().toBuffer({resolveWithObject:true});
 for(let y=0;y<95;y++)for(let x=0;x<71;x++){
  const edge=Math.min(y,94-y);const cut=edge===0?4:edge===1?2:edge===2?1:0;
  const a=(y*71+x)*4+3;
  if(x<cut||x>=71-cut||data[a]<16)data[a]=0;
 }
 return sharp(data,{raw:{width:71,height:95,channels:4}}).png().toBuffer();
}
(async()=>{
 fs.mkdirSync(final,{recursive:true});
 const sprites={};const manifest=[];
 for(const [key,name]of Object.entries(input)){
  const file=path.join(source,name);sprites[key]=await card(file);
  fs.copyFileSync(file,path.join(final,name));
  const meta=await sharp(file).metadata();manifest.push({key,source:name,width:meta.width,height:meta.height});
 }
 const order=['bijie','guanyin','shishang','caixing','shayin'];
 sprites.natal=await sharp({create:{width:355,height:95,channels:4,background:{r:0,g:0,b:0,alpha:0}}})
  .composite(order.map((key,i)=>({input:sprites[key],left:i*71,top:0}))).png().toBuffer();
 sprites.patterns=await sharp({create:{width:355,height:570,channels:4,background:{r:0,g:0,b:0,alpha:0}}})
  .composite(patternOrder.map((key,i)=>({input:sprites['mp_'+key],left:(i%5)*71,top:Math.floor(i/5)*95}))).png().toBuffer();
 for(const scale of[1,2]){
  const dir=path.join(out,`${scale}x`);fs.mkdirSync(dir,{recursive:true});
  for(const key of['deck','fortune','natal','patterns','legacy_booster'])
   await sharp(sprites[key]).resize(71*scale*(['natal','patterns'].includes(key)?5:1),95*scale*(key==='patterns'?6:1),{kernel:'nearest'}).png().toFile(path.join(dir,key+'.png'));
 }
 fs.writeFileSync(path.join(root,'assets/final/export-manifest.json'),JSON.stringify({
  source:'built-in ImageGen',method:'aspect-preserving contain; nearest pixels; standard stepped corner alpha; 2x from1x',
  runtime_atlases:['deck','fortune','natal','patterns','legacy_booster'],natal_order:order,pattern_order:patternOrder,sources:manifest},null,2)+'\n');
 console.log('Exported 5 real atlases at1x and2x, including26 pattern cells.');
})().catch(e=>{console.error(e);process.exitCode=1;});
