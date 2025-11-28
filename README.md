# Sui Next.js dApp

A Next.js application with Sui SDK and dApp Kit integration.

## Getting Started

1. Install dependencies:
```bash
npm install
# or
yarn install
# stamp-event

`Mainnet`
### Stamp
- **Package**: `0xf469c36f014c1cd531ed119425e341beeaa569615c144e65a52cf2d0613d4fcb`
- **UpgradeCap**: `0x162e8837330935c317b0dd52c2ab829b0dca2060897a11e9a0fa6c238b9dfa86`
- **Publisher**: `0xfca2f7ec19fa71acad6ea7fbc5301da7bcb614a58bc37d40d2f3f6cbe5cd8c98`
- **Config**: `0x5e5705f3497757d8e120e51143e81dab8e58d24ff1ba9bcf1e4af6c4b756fb9f`
- **AdminCap**: `0x535681c0cd88aea86ef321958c3dff33ea3aa3e5400ddd9f44fb57f214ed0f66`


### CollectionTypes
- **SuiFundamentalsDiscordVIPPass**: `0xa66240bda1ccf0e28363a87c05a8972dc674516c06cdaa4cefcd5711f3d4cac1::collections::SuiFundamentalsDiscordVIPPass`

## Usage Examples

### Single Mint
Mint a single stamp to a specific address:

```
sh batch_mint.sh "discord_vip_pass.csv" 0xa66240bda1ccf0e28363a87c05a8972dc674516c06cdaa4cefcd5711f3d4cac1::collections::SuiFundamentalsDiscordVIPPass "Sui Fundamentals Discord VIP Pass"
```
