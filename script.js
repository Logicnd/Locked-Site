document.getElementById('whoami').addEventListener('click', () => {
  const id = generateAnonId();
  const info = {
    id,
    ts: new Date().toISOString(),
    note: 'This is an anonymized client-side ID only.'
  };
  document.getElementById('info').textContent = JSON.stringify(info, null, 2);
});

function generateAnonId(){
  // lightweight deterministic-ish id from user agent + time slice (client-side only)
  const ua = navigator.userAgent || '';
  const now = Math.floor(Date.now()/1000/60); // minute bucket
  const s = ua + '|' + now;
  return sha1(s).slice(0,12);
}

function sha1(str){
  // simple JS implementation for short strings
  function rotl(n,s){ return (n<<s)|(n>>>(32-s)); }
  const utf8 = new TextEncoder().encode(str);
  const words = [];
  for(let i=0;i<utf8.length;i++){ words[i>>2] |= utf8[i] << (24 - (i%4)*8); }
  const l = utf8.length*8;
  words[l>>5] |= 0x80 << (24 - l%32);
  words[((l+64>>9)<<4)+15] = l;
  let H0=0x67452301, H1=0xEFCDAB89, H2=0x98BADCFE, H3=0x10325476, H4=0xC3D2E1F0;
  const W = new Array(80);
  for(let i=0;i<words.length;i+=16){
    for(let t=0;t<16;t++) W[t]=words[i+t]>>>0;
    for(let t=16;t<80;t++) W[t]=rotl(W[t-3]^W[t-8]^W[t-14]^W[t-16],1)>>>0;
    let a=H0,b=H1,c=H2,d=H3,e=H4;
    for(let t=0;t<80;t++){
      let s=Math.floor(t/20); let T=(rotl(a,5) + ([ (b&c)|(~b&d), b^c^d, (b&c)|(b&d)|(c&d), b^c^d ][s]) + e + W[t] + [0x5A827999,0x6ED9EBA1,0x8F1BBCDC,0xCA62C1D6][s])>>>0;
      e=d; d=c; c=rotl(b,30)>>>0; b=a; a=T;
    }
    H0=(H0+a)>>>0; H1=(H1+b)>>>0; H2=(H2+c)>>>0; H3=(H3+d)>>>0; H4=(H4+e)>>>0;
  }
  return [H0,H1,H2,H3,H4].map(n=>('00000000'+n.toString(16)).slice(-8)).join('');
}
