# Known issues / 已知问题

## K001 — 官印相生结构漏识别（未修复）

生日匹配中的官印组合规则目前只接受正印，并同时要求官印满足固定藏根/权重门槛、月令主类已是正官。它可能遗漏偏印参与或其他月令下可见的官生印、印生身关系。

这属于规则模型限制，不是输入控件失效。检测关系是否存在、评价其力量、判断是否成格应当分层；不能靠特判某个生日来修正。0.6新增预设入口没有修改这一算法。预设模式不调用排盘与分类器，可用于直接选择游戏难度。

The birthday classifier can miss officer-resource relationships because it requires the direct-resource subtype, fixed root/weight thresholds, and a restrictive month-led primary category. This remains unresolved. Recognizing a relationship and evaluating its strength/formation must be treated separately. Version0.6 changes entry modes, not these classification rules.

## Verification is not semantic accuracy / 验收边界

- 先前952,056个日期时辰/交节边界检查证明没有空分类，不证明传统格局判定准确。
- 所有档次、门槛、奖励均为游戏规则，不评价现实人生。
- 固定公历北京时间UTC+8，未做真太阳时、出生地或历史夏令时校正。
- 自动与隔离实机测试不是所有MOD组合、所有卡牌八底注通关的证明。

No personal birth chart, save file, credential, or proprietary game dump is needed to reproduce this limitation and none is included here.
