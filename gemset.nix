{
  activesupport = {
    dependencies = ["base64" "bigdecimal" "concurrent-ruby" "connection_pool" "drb" "i18n" "json" "logger" "minitest" "securerandom" "tzinfo" "uri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03m2vjhq3nmc8c3hpivxhvkjd8igg16nmv0p2fgdsgacppgy1991";
      type = "gem";
    };
    version = "8.1.3";
  };
  async = {
    dependencies = ["console" "fiber-annotation" "io-event" "metrics" "traces"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ah038cvb5k7vr29z5jkjhdwqpinrchglz87i1bv9fzjfc07666z";
      type = "gem";
    };
    version = "2.39.0";
  };
  async-container = {
    dependencies = ["async"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g9lcawa16wjgq131ngczx54vdy4qqda3lqlh8iijlncnh5rapch";
      type = "gem";
    };
    version = "0.34.5";
  };
  async-http = {
    dependencies = ["async" "async-pool" "io-endpoint" "io-stream" "metrics" "protocol-http" "protocol-http1" "protocol-http2" "protocol-url" "traces"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0v3q2kn9j5vfag7b4zv2vc1i4jkrqjz1pc109df6vh04q9cd8g8c";
      type = "gem";
    };
    version = "0.95.1";
  };
  async-http-cache = {
    dependencies = ["async-http"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mnzzlq0bnya0hlzrz0bl66r7qw5a3173cjd1fsicbqqjgqd2f10";
      type = "gem";
    };
    version = "0.4.6";
  };
  async-ollama = {
    dependencies = ["async" "async-rest"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1myl413dynl0z0rwmf3sswly9yamz5ysk8nwb3wm2230ljdlqp0h";
      type = "gem";
    };
    version = "0.10.3";
  };
  async-pool = {
    dependencies = ["async"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vg3lwb3yhq0rad3dm00vp35vrahkbxgl4kx3d2rqkdh09xs2hqa";
      type = "gem";
    };
    version = "0.11.2";
  };
  async-rest = {
    dependencies = ["async-http" "protocol-url"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1swmgq79knydk05ylkhv43x4l6yqyclbh4pwchxaasajyrkx9c3j";
      type = "gem";
    };
    version = "0.20.0";
  };
  async-service = {
    dependencies = ["async" "async-container" "string-format"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0q9vwq9iidm7426s23dz90as44cqygp9f82ck4px8m2n2j468qc4";
      type = "gem";
    };
    version = "0.22.0";
  };
  async-utilization = {
    dependencies = ["console"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d7k3nrmzi3gwlv1z9g3pb72f3j2bszfr8019b0kzqlgjkh2f6i0";
      type = "gem";
    };
    version = "0.3.2";
  };
  bake = {
    dependencies = ["bigdecimal" "samovar"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1izlqnz0828mgdq04s1w291ky912w6jzcg5iwch7gc8l2pkcgylb";
      type = "gem";
    };
    version = "0.24.1";
  };
  bake-gem = {
    dependencies = ["console"];
    groups = ["maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14qvrxrcy1g6as6nbcs7di20kvzx46yw0bwczjaa3v6p8dil2p27";
      type = "gem";
    };
    version = "0.13.1";
  };
  bake-modernize = {
    dependencies = ["async-http" "async-ollama" "bake" "build-files" "markly" "rugged"];
    groups = ["maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1aygmnhri2zhxhgzisvv60q46fqbyakrjqx5290q2cg2qi7i49ij";
      type = "gem";
    };
    version = "0.55.0";
  };
  bake-releases = {
    dependencies = ["bake" "markly"];
    groups = ["maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1q1kwrxfv9z4l7c94kid52z15jiqvg1snmr9qdrh7p91l5qwm4pn";
      type = "gem";
    };
    version = "0.5.4";
  };
  base64 = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yx9yn47a8lkfcjmigk79fykxvr80r4m1i35q82sxzynpbm7lcr7";
      type = "gem";
    };
    version = "0.3.0";
  };
  bigdecimal = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g9zi8c4i7g8zz0c3hxrw6mblrjvgn7akys60clb9si7c1k1gljk";
      type = "gem";
    };
    version = "4.1.2";
  };
  build-files = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g9p6dhnycc2649fd2pi5jzklyqn2cjbvggccqkjqgalajf971hh";
      type = "gem";
    };
    version = "1.10.2";
  };
  concurrent-ruby = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1aymcakhzl83k77g2f2krz07bg1cbafbcd2ghvwr4lky3rz86mkb";
      type = "gem";
    };
    version = "1.3.6";
  };
  connection_pool = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "02ifws3c4x7b54fv17sm4cca18d2pfw1saxpdji2lbd1f6xgbzrk";
      type = "gem";
    };
    version = "3.0.2";
  };
  console = {
    dependencies = ["fiber-annotation" "fiber-local" "json"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1k0dxi072mz8j72r32kkzpky825hn092hb8hdxh4rz3yd5sbv7w6";
      type = "gem";
    };
    version = "1.34.3";
  };
  date = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1h0db8r2v5llxdbzkzyllkfniqw9gm092qn7cbaib73v9lw0c3bm";
      type = "gem";
    };
    version = "3.5.1";
  };
  debug = {
    dependencies = ["irb" "reline"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1djjx5332d1hdh9s782dyr0f9d4fr9rllzdcz2k0f8lz2730l2rf";
      type = "gem";
    };
    version = "1.11.1";
  };
  decode = {
    dependencies = ["prism" "rbs"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mp1ha7sg6l6f5dqwidxwnpm7lj7my5vsxwz7nlnpg7lqsj0fnvb";
      type = "gem";
    };
    version = "0.27.0";
  };
  drb = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wrkl7yiix268s2md1h6wh91311w95ikd8fy8m5gx589npyxc00b";
      type = "gem";
    };
    version = "2.2.3";
  };
  erb = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ncmbdjf2bwmk0jf5cxywns9zbxyfiy4h4p3pzi7yddyjhv81qrq";
      type = "gem";
    };
    version = "6.0.4";
  };
  falcon = {
    dependencies = ["async" "async-container" "async-http" "async-http-cache" "async-service" "async-utilization" "localhost" "openssl" "protocol-http" "protocol-rack" "samovar"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fwp7i3f9gvsg0qyn33i522fvj0gh1w25byq1plv4jsmwfnbv1q2";
      type = "gem";
    };
    version = "0.55.3";
  };
  fiber-annotation = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00vcmynyvhny8n4p799rrhcx0m033hivy0s1gn30ix8rs7qsvgvs";
      type = "gem";
    };
    version = "0.2.0";
  };
  fiber-local = {
    dependencies = ["fiber-storage"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01lz929qf3xa90vra1ai1kh059kf2c8xarfy6xbv1f8g457zk1f8";
      type = "gem";
    };
    version = "1.1.0";
  };
  fiber-storage = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qa0j9qjwav9xb0n3isx0rbh0942xrfback392n6vs8bidnmp3pl";
      type = "gem";
    };
    version = "1.0.1";
  };
  hana = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03cvrv2wl25j9n4n509hjvqnmwa60k92j741b64a1zjisr1dn9al";
      type = "gem";
    };
    version = "1.3.7";
  };
  http-accept = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "03shmn4nn1cwqwhjfii2ad7gz7s4481b5ipmalsy90pp43nisj7q";
      type = "gem";
    };
    version = "2.2.1";
  };
  i18n = {
    dependencies = ["concurrent-ruby"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1994i044vdmzzkyr76g8rpl1fq1532wf0sb21xg5r1ilj5iphmr8";
      type = "gem";
    };
    version = "1.14.8";
  };
  io-console = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1k0lk3pwadm2myvpg893n8jshmrf2sigrd4ki15lymy7gixaxqyn";
      type = "gem";
    };
    version = "0.8.2";
  };
  io-endpoint = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0f1kzf4d5qgqgfjh52a8pf3pii5dmav6ib0zq4wmicqnq5kggsiz";
      type = "gem";
    };
    version = "0.17.2";
  };
  io-event = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "143v7rhfq2kv10nadsq9fkhf2x0jf240jgq9wmvs9510pcyxjh9b";
      type = "gem";
    };
    version = "1.16.0";
  };
  io-stream = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dhnkjf59ayw5xi873a939i63d47lrlqcpphvv73xprb635vq96f";
      type = "gem";
    };
    version = "0.13.0";
  };
  irb = {
    dependencies = ["pp" "prism" "rdoc" "reline"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qs8a9vprg7s8krgq4s0pygr91hclqqyz98ik15p0m1sf2h5956y";
      type = "gem";
    };
    version = "1.18.0";
  };
  json = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0n9ch455pnvl9vxs2f3j77bpdmxg5g3mn3vyr9wxa0a87raii2i1";
      type = "gem";
    };
    version = "2.19.5";
  };
  json_schemer = {
    dependencies = ["bigdecimal" "hana" "regexp_parser" "simpleidn"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15p31bq932bfpsi1wgrkgwm71l7z1h1w53q6vl44w6kjrr6gn09g";
      type = "gem";
    };
    version = "2.5.0";
  };
  kube_cluster = {
    dependencies = ["activesupport" "kube_kubectl" "kube_schema"];
    groups = ["default"];
    platforms = [];
    source = {
      path = ./.;
      type = "path";
    };
    version = "1.8.0";
  };
  kube_kubectl = {
    dependencies = ["debug" "json_schemer" "rubyshell" "shellwords" "string_builder"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nh84nr2021yig5s6zjhjmll8vkv6wd7gjxd51i1r34cgly59zlj";
      type = "gem";
    };
    version = "2.0.9";
  };
  kube_schema = {
    dependencies = ["json_schemer" "rubyshell"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1f8nazb6glzxkms0paqsn9x0zihmgj739l2shnwafhzaxgxcqy4z";
      type = "gem";
    };
    version = "1.11.0";
  };
  lefthook = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0r8vwq96i3wfsb3c2q0qjl3nssadwmlrgavf06wfi2d6isyhd76c";
      type = "gem";
    };
    version = "2.1.10";
  };
  localhost = {
    dependencies = ["bake"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0097kdsp2fwkps57f8ypc12dqzf4dg4glzn1i32ljjgnnhjshznz";
      type = "gem";
    };
    version = "1.8.0";
  };
  logger = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00q2zznygpbls8asz5knjvvj2brr3ghmqxgr83xnrdj4rk3xwvhr";
      type = "gem";
    };
    version = "1.7.0";
  };
  mail = {
    dependencies = ["logger" "mini_mime" "net-imap" "net-pop" "net-smtp"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ha9sgkfqna62c1basc17dkx91yk7ppgjq32k4nhrikirlz6g9kg";
      type = "gem";
    };
    version = "2.9.0";
  };
  mapping = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18jdbz3x6cvprhsw7jiv44xi6wklric0rq6iznm6xm7c40fr6x12";
      type = "gem";
    };
    version = "1.1.3";
  };
  markly = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04ammhfwf91r7kh7iiz6kw1mjql250bchx0z2yggq7jv72gdfw3g";
      type = "gem";
    };
    version = "0.16.0";
  };
  metrics = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wlh0g4xmfqa41dsh4m3514q3jcvy6jx97mwn6ayj62ir6xdbpk1";
      type = "gem";
    };
    version = "0.15.0";
  };
  mime-types = {
    dependencies = ["logger" "mime-types-data"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mjyxl7c0xzyqdqa8r45hqg7jcw2prp3hkp39mdf223g4hfgdsyw";
      type = "gem";
    };
    version = "3.7.0";
  };
  mime-types-data = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1k28j6ww8rf43r5i8278jvm2cq3pnzsvqm7yqpb4p93kadjlq726";
      type = "gem";
    };
    version = "3.2026.0414";
  };
  mini_mime = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vycif7pjzkr29mfk4dlqv3disc5dn0va04lkwajlpr1wkibg0c6";
      type = "gem";
    };
    version = "1.1.5";
  };
  minitest = {
    dependencies = ["drb" "prism"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wfnqyfayx9n9j7x871v2ars4hjhfisi1dl24fa64ylq3mns6ghm";
      type = "gem";
    };
    version = "6.0.6";
  };
  msgpack = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cnpnbn2yivj9gxkh8mjklbgnpx6nf7b8j2hky01dl0040hy0k76";
      type = "gem";
    };
    version = "1.8.0";
  };
  net-imap = {
    dependencies = ["date" "net-protocol"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ax0f0r97jm83q462vsrcbdxprs894fyyc44v62c48ihgb39hmcs";
      type = "gem";
    };
    version = "0.6.4";
  };
  net-pop = {
    dependencies = ["net-protocol"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wyz41jd4zpjn0v1xsf9j778qx1vfrl24yc20cpmph8k42c4x2w4";
      type = "gem";
    };
    version = "0.1.2";
  };
  net-protocol = {
    dependencies = ["timeout"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a32l4x73hz200cm587bc29q8q9az278syw3x6fkc9d1lv5y0wxa";
      type = "gem";
    };
    version = "0.2.2";
  };
  net-smtp = {
    dependencies = ["net-protocol"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dh7nzjp0fiaqq1jz90nv4nxhc2w359d7c199gmzq965cfps15pd";
      type = "gem";
    };
    version = "0.5.1";
  };
  openssl = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hj7wwp4r3jhvnyd8ik85wbs25cq1w61r28pv6ddyn5fd0lasdqh";
      type = "gem";
    };
    version = "4.0.2";
  };
  pp = {
    dependencies = ["prettyprint"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xlxmg86k5kifci1xvlmgw56x88dmqf04zfzn7zcr4qb8ladal99";
      type = "gem";
    };
    version = "0.6.3";
  };
  prettyprint = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14zicq3plqi217w6xahv7b8f7aj5kpxv1j1w98344ix9h5ay3j9b";
      type = "gem";
    };
    version = "0.2.0";
  };
  prism = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11ggfikcs1lv17nhmhqyyp6z8nq5pkfcj6a904047hljkxm0qlvv";
      type = "gem";
    };
    version = "1.9.0";
  };
  protocol-hpack = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14ddqg5mcs9ysd1hdzkm5pwil0660vrxcxsn576s3387p0wa5v3g";
      type = "gem";
    };
    version = "1.5.1";
  };
  protocol-http = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fvpza7nnbyd3nfxkn5gych6diwns386g2ib9s6azh99c3sz5hg1";
      type = "gem";
    };
    version = "0.62.2";
  };
  protocol-http1 = {
    dependencies = ["protocol-http"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1syqgaklsn9rf11xmll2s3ms7jvpd5zjng9jdb3r8pbgv963z6z4";
      type = "gem";
    };
    version = "0.39.0";
  };
  protocol-http2 = {
    dependencies = ["protocol-hpack" "protocol-http"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11kl6768hpzgvvvlpyvmr74v0jqf2vslcwngs3643cl2h3brrj5s";
      type = "gem";
    };
    version = "0.26.0";
  };
  protocol-rack = {
    dependencies = ["io-stream" "protocol-http" "rack"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hwz5bb3wcx4lkprigsgfa4vqlx33jcxc01pc2d89ybyj92x518i";
      type = "gem";
    };
    version = "0.22.1";
  };
  protocol-url = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qd9vsn9sif58swfqsyj429aynqyv6hpgbzxqrd83baidcxw1m34";
      type = "gem";
    };
    version = "0.4.0";
  };
  psych = {
    dependencies = ["date" "stringio"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0x0r3gc66abv8i4dw0x0370b5hrshjfp6kpp7wbp178cy775fypb";
      type = "gem";
    };
    version = "5.3.1";
  };
  rack = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hhjy9gcp52dzij05gmidqac8g28ski5xm67prwmdqmjfcgqxmsy";
      type = "gem";
    };
    version = "3.2.6";
  };
  rackula = {
    dependencies = ["falcon" "samovar" "variant"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qdv10k36c3qmfpv6321in5k7x9xgpm55h25d0q8hbb5ph74p0j6";
      type = "gem";
    };
    version = "1.4.1";
  };
  rake = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "009p524zl0p0kfa65nii8wdmaigkmawv9pbvlcffky7islmmp0nb";
      type = "gem";
    };
    version = "13.4.2";
  };
  rbs = {
    dependencies = ["logger" "prism" "tsort"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09ggg2zk0qrh0mc3fa23xjbn2gzqxd0jfqj6qm6460ydcqg6fxdg";
      type = "gem";
    };
    version = "4.0.2";
  };
  rdoc = {
    dependencies = ["erb" "psych" "tsort"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14iiyb4yi1chdzrynrk74xbhmikml3ixgdayjma3p700singfl46";
      type = "gem";
    };
    version = "7.2.0";
  };
  regexp_parser = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fwfw26a32rps78920nn29shqg2zmqv72i89j1fap41isshida9m";
      type = "gem";
    };
    version = "2.12.0";
  };
  reline = {
    dependencies = ["io-console"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0d8q5c4nh2g9pp758kizh8sfrvngynrjlm0i1zn3cnsnfd4v160i";
      type = "gem";
    };
    version = "0.6.3";
  };
  rubyshell = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dkaj6a038m23r2xph0k2jc03i6aq8xzqmf17qpjprb2b50jimgz";
      type = "gem";
    };
    version = "1.5.0";
  };
  rugged = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1b7gcf6pxg4x607bica68dbz22b4kch33yi0ils6x3c8ql9akakz";
      type = "gem";
    };
    version = "1.9.0";
  };
  samovar = {
    dependencies = ["console" "mapping"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "104y60zqn1mznv1smbzzvhljam193w8w2886c2yf6w87b381vff3";
      type = "gem";
    };
    version = "2.4.1";
  };
  scampi = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04x366dnw081ajg6qbw24i6afisv7fsgyvvwnvlr000ah48k3d66";
      type = "gem";
    };
    version = "1.0.0";
  };
  securerandom = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cd0iriqfsf1z91qg271sm88xjnfd92b832z49p1nd542ka96lfc";
      type = "gem";
    };
    version = "0.4.1";
  };
  shellwords = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "151gsdn2ci3ykvwxhmbz2yj3ar9g6gsc7gasvrr19xz23mwmlsdq";
      type = "gem";
    };
    version = "0.2.2";
  };
  simpleidn = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0a9c1mdy12y81ck7mcn9f9i2s2wwzjh1nr92ps354q517zq9dkh8";
      type = "gem";
    };
    version = "0.2.3";
  };
  string-format = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1xlsg0m748bcb4vgvmjxlfsif6nnl8pz6ja52c91y1kb24a1r65w";
      type = "gem";
    };
    version = "0.2.0";
  };
  string_builder = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "14ck60j7zp1vbw8amzgbfzfb70qd5rjjz1lp8q557z0k4pmqhgii";
      type = "gem";
    };
    version = "1.2.4";
  };
  stringio = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1q92y9627yisykyscv0bdsrrgyaajc2qr56dwlzx7ysgigjv4z63";
      type = "gem";
    };
    version = "3.2.0";
  };
  thread-local = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ryjgfwcsbkxph1l24x87p1yabnnbqy958s57w37iwhf3z9nid9g";
      type = "gem";
    };
    version = "1.1.0";
  };
  timeout = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1jxcji88mh6xsqz0mfzwnxczpg7cyniph7wpavnavfz7lxl77xbq";
      type = "gem";
    };
    version = "0.6.1";
  };
  traces = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05722prvh34n96irnxa762wz0yj2nyrz70ab2zby3b6snjf69wc0";
      type = "gem";
    };
    version = "0.18.2";
  };
  tsort = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17q8h020dw73wjmql50lqw5ddsngg67jfw8ncjv476l5ys9sfl4n";
      type = "gem";
    };
    version = "0.2.0";
  };
  tzinfo = {
    dependencies = ["concurrent-ruby"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16w2g84dzaf3z13gxyzlzbf748kylk5bdgg3n1ipvkvvqy685bwd";
      type = "gem";
    };
    version = "2.0.6";
  };
  uri = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ijpbj7mdrq7rhpq2kb51yykhrs2s54wfs6sm9z3icgz4y6sb7rp";
      type = "gem";
    };
    version = "1.1.1";
  };
  utopia = {
    dependencies = ["bake" "concurrent-ruby" "console" "http-accept" "irb" "mail" "mime-types" "msgpack" "net-smtp" "protocol-url" "rack" "samovar" "traces" "variant" "xrb"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0d6njl2lw3j68nd34wm6szr7yk8h2xq6a15b1sv8r49rpcddi3l8";
      type = "gem";
    };
    version = "2.32.1";
  };
  utopia-project = {
    dependencies = ["decode" "falcon" "markly" "rackula" "thread-local" "utopia"];
    groups = ["maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0j4jq3b9y6mly85s16yy6alrlyydzinylh4zly9v7y2bwd2y5604";
      type = "gem";
    };
    version = "0.40.0";
  };
  variant = {
    dependencies = ["thread-local"];
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0mizrq6819baz3s0zqwb5qz2dx21k3d0kav6alrcn14kvkfqzssk";
      type = "gem";
    };
    version = "0.1.1";
  };
  xrb = {
    groups = ["default" "maintenance"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0w08kwxw9yll1p2sn2fhczzwgnx6q79ybl1xvkivnn3vig6jls0y";
      type = "gem";
    };
    version = "0.11.2";
  };
}
