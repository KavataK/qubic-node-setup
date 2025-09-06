# Qubic Node Setup

This repository contains an automated Bash script that installs all required dependencies and sets up the environment for running a Qubic node on a fresh Linux server.

Current version: 1.0.0

**Note:** The script uses files from epoch 172 of the mainnet, except for the spectrum file which is custom.
> ⚠️ This version is optimized for testing and development. Not recommended for production environments.

## 🧾 Minimum Requirements

- **Operating System:** Ubuntu 22.04 (clean install)
- **Storage:** At least 50 GB of free disk space
- **Memory (RAM):** 64 GB or more
- **Permissions:** Must be run as **root**

## 🔧 What It Does

- Creates working directories
- Downloads and extracts necessary archives
- Installs required software packages and libraries
- Installs Docker and Docker Compose
- Installs VirtualBox and Extension Pack
- Clones necessary Qubic repositories
- Builds `qubic-cli` and `qlogging` from source
- Copies configuration files
- Patches IP addresses in Docker configs
- Makes scripts executable

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/KavataK/qubic-node-setup.git
cd qubic-node-setup

# Run the install script as root
sudo bash install.sh
```

## 🔄 Update existing installation

To update an already installed server to the latest version:

```bash
cd /root
curl -fsSL https://raw.githubusercontent.com/KavataK/qubic-node-setup/main/update.sh -o update.sh
bash update.sh
```

Notes:
- The updater is cumulative and idempotent. Servers on older versions will fetch all required files to reach the latest version.
- You can force reapplying the same version:
```bash
bash update.sh --force
```

## 🧪 Test Network Deployment

To deploy a test network, run the following commands:

```bash
cd /root/qubic/qubic_docker
# Example: ./deploy.sh https://github.com/qubic/core/tree/testnets/release-254
./deploy.sh {your link to the GitHub repository}
```

> ⚠️ The network will only deploy if the [commit](https://github.com/qubic/core/commit/03cf4ca46a1901c73d387c742be5f28f2ec689e6) is added.

### Redeploying the Network

To redeploy the network, first clean up the running network:

```bash
./cleanup.sh
```

After cleanup, you can use the deploy.sh script again to deploy a new network.

---

## 🌐 Mainnet Deployment

1) Place current epoch files into `/root/qubic/filesForVHDMN/`

- Put the latest `universe.XXX`, `spectrum.XXX`, and contract files (e.g., `contract0000.XXX`, `contract0001.XXX`, ...).

2) Provide public peers in `peersMN.txt`

- Edit `/root/qubic/qubic-efi-cross-build/peersMN.txt` and add IPs from the live network page: [app.qubic.li/network/live](https://app.qubic.li/network/live). Remove any placeholder/header lines.

3) Provide seeds (optional)

- Put seeds in `/root/qubic/qubic-efi-cross-build/seedsMN.txt` (one per line).

4) Run mainnet deployment

```bash
cd /root/qubic/qubic_docker
./deploy.sh https://github.com/qubic/core
```

## 🧪 Hackathon Version

For a version tailored specifically for hackathons, use the `hackathon` branch:

```bash
git clone -b hackathon https://github.com/KavataK/qubic-node-setup.git
cd qubic-node-setup
sudo bash install.sh
```

## 💰 Funded Seeds

Seeds with funds:

```
10х100bln qus
gtfgjhtoxcddbxrydatevcmildkmqeiezwgztpwseihqhqxmoamxfak
ytcltfdvfjvskmarrjxloxkjrwtbjbepzjphowjfszldyjscrmztmor
ahbpfnqltlotcyyaljwjouoheepykysdsokuazxlwecrwkuesxhahrx
ouyxwcntrhdkmqrjvvpuhpakdjtvcmwihaezumfqkdlhfdfpwxkhttf
nqgjkedtrfrvjessgckewozmjyvzzqkpblzbkistgimvtsdqezykpfh
otdnmvfolpdmchvtlqxviekibqtmngecsabuuhlseqwjzouevdniwft
ulprhzbvzxvpkcigfdiqghrjrcarowfkviwnyciwrcykbhrpjxomvlt
mziquwzssfckwvhusrvqowtoljeulqalnzlrvovhbemikzrowxoeaig
orxlpszaoguhglnkclcqnkvfzhqzzjnuisfvkwwuztkhqpwauexemdy
iaobrqjfipbwancelebhkjhksghalrbovgfnrrejpvpblmchsliscqw

10x50bln qus
slmvcerjvoncdlluydvilhuddusewxgoshuhgwelljzjykfllywlhon
jaceqhnbufbcyoninbynpmglseulbuabscdrqttdwlflirpxnhnknpz
pyvsehwfkqwihkhynsqggnewzbuiheoqaozlxdosmvcoayaauyrqtuu
ughdrtzbfhqhmzsnoxvalppxbgmbfazcgvocacdkfrwnolzvrzqzbny
krmnalawaxnhqvruzumckiefwbelpbvsyivvprfmsnhyfdwgxxvjsfr
uggcbsmkggyynepudfecjnuhmrguihspdcojltjgvkcowtrviatzajv
gmcccpxjvdfqlanaekolzxqstbdnvxurvfzxvqrsyjjcotmdsjrkomc
kxpsjbvgaahjzltbnqdhehzdinicvxnvvutliqifadbiyqldgayhfzy
hluajlytdqztjtefcbzcwkrdaopvaaaruaexfcnptuolussvepekjbx
vyvymjcxxstbzthfflpsgjvgjlbxrctmorynuelhnwkghuwxmbszdqf

30x20bln qus
ajobheaecrimndbvamokhdgdnjncmghbweiiygxltzjvmygzzdpcjls
wlwqwbwwqycpfxrpqijexjxarmplfjexvxejuhmsmoknhaurnidfhdn
arvcleojlesnkrfxaclxdbebyuooscjgpugivjovovqquhsvlrlczau
uttkvcscihmpbugpyimindvhgbphoftnbgqloeewsiddbbmybokfrbj
ilfysrosmdeqxeexvaaykoabogngebzjpcrytghqosorrcqdpckueiw
syzhqplcrpduitgopmtzjjpasxyzvacruosmztplukmdrbkyepljcev
kbertedhbrttsxnrdonslcxexjqmyziyuhairmvqddahhihftntteek
glfneriumdnnthyqahxiehatoxpvtmspmbkshysuhgvoqgijvbkvghq
shkbsozazkgnkbmpidafxnnppxwearqhsdnbfvnyexiyyxsorlsspeu
kyxliechhheapklpywhozyuxemovxpldwlgmgfxtugxmmaucvvurhmo
vluuhkrdfzrntmfagjwllcrsqxebhqhkilrgmcgqepkgutmfipspqcy
kclgtseibylaqmvphbyoyaxfwyiwwkxgdhoxcfvzjbwmzqyomxqsurn
ypgqvydndxunaaalfuwesrdixzhtsmffrrfjyplvgomiinqrpadmkan
zkapkcrymskbwoeadbydbhfzxrxxetxtngyawtaexjyrwimgcsshmfq
cothzmwfilwfiaulduoqaeydjrfkaythkjuxicobzpkyeqtyfrbmlsu
fyoudnjucgqcwycbnprinbpadfyoqdgqnfnfkgvbslxmjllyqcgjeur
fwfizoclxzpzwjcvxlezmahylvaptuitiqjpfaxodfhzpvgntewkbly
bmtzadjewzygphnwevsubamujtujvwezefozisfqwmrqmwmjttjnyis
zzbooznrtdohoibtdqbssgdkzypzbqdcxpwiwjedkrqmwhuadllfhbr
oeonabxsnxcwenutwqrpnjtbrmfuafimiwcotresqfrgnzlasvlzvxg
gpjknabsmurmoebjlexdxitohnrttdlblvyimphvskmcstbpqeddexs
vvqvnsxllskksyaonlhuwsrilpxxffgdftynuictvklyrcnwzpjrvft
iulkoaotegjwuwkoeznzptcbcwlxochcefludunbmbbgpyetnsxzsec
bwlflypmycehaeyhhzdtoluuotuhisbenryaensldkadgstmttjgwep
lmvtwxhanknjkungrqkrsxdcinltipioqfalumviacpnffelvjijzbj
tncfnabhlhonmapqoponljskargrtdtxtgaazlwytibbpsinrinmsjp
gilmkaiizpmqpinljrnhdtepzrmvwjdfxswihhwqmbjxqelymwyfary
mrgpekwtzbverjpokwilzaslvydxisvvbrcrzoqckheuldykdinlwvy
qhvplvdwakvggvmdlyrdkmjkrvtuwegnfkwvvvjdlcmtexrawisbeze
cineyqynjwalyadoqonozxfctnwyfsjnvwdcndhlrseiiqbhhcowudu
```


