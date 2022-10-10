* INonfungiblePositionManager:非同质位置管理器，提供流动mint，增加，减少操作，以及收益费用的收集；在mint流动性时，同时会创建基于位置的NFT；
* SwapRouter: swap操作：根据输入token，swap出尽可能大的另一个token；swap评估操作：根据输入的token数量，需要输入的最小另外一个token的数量；
* V3Migrator: 从V2流动性，迁移到V3，可以指定迁移流动性百分比，没有迁移的将会退回给；



# TODO

NonfungiblePositionManager