* INonfungiblePositionManager:非同质位置管理器，提供流动mint，增加，减少操作，以及收益费用的收集；在mint流动性时，同时会创建基于位置的NFT；
* SwapRouter: swap操作：根据输入token，swap出尽可能大的另一个token；swap评估操作：根据输入的token数量，需要输入的最小另外一个token的数量；

多路径的的情况编码为：token0+fee01+token1+fee12+token2+fee23+token3+fee34+token4+..., 这种是针对swap是如果没有对应的交易对pair，则从不同的
交易池进行swap， 不如使用token0，想swap token3，整个swap的路径为（token0+fee01+token1，token1+fee12+token2，token2+fee23+token3）

* V3Migrator: 从V2流动性，迁移到V3，可以指定迁移流动性百分比，没有迁移的将会退回给；

Path：交易池路径工具，路径实际编码为token0地址+fee+token1地址  ；
PoolAddress:交易池地址工具，根据交易池key，包含token0地址，token1地址，fee，生成交易池地址；
PeripheryPaymentsWithFee：提供带续费费用的支付，支持eth和token；
PeripheryPayments：提供支付操作，支持eth和token；




# TODO

NonfungiblePositionManager