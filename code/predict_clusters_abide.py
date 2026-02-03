# -*- coding: utf-8 -*-
"""
Apply trained ABIDE SVM (5–12.9y ASD Male) to ABIDE remaining subjects (>=13y ASD Male)
@author: xueru
"""

import os
import pandas as pd
import joblib

# =========================================================
# 1. 路径设置
# =========================================================

model_file = (
    "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/"
    "trained_svm_model.pkl"
)

data_file = (
    "/Users/xuerufan/DCM-Project-PhD-Study3-/supplement/"
    "abide_All_centile_240315.csv"
)

output_file = (
    "/Users/xuerufan/DCM-Project-PhD-Study3-/output/"
    "abide_cluster_predictions_13maleASD.csv"
)

# =========================================================
# 2. 加载模型
# =========================================================

loaded_model = joblib.load(model_file)
print("✓ Trained SVM model loaded")

# =========================================================
# 3. 读取 ABIDE 数据
# =========================================================

data = pd.read_csv(data_file)
print(f"✓ Original dataset size: {data.shape}")

# =========================================================
# 4. 严格筛选预测人群（方法学关键）
# =========================================================

# 仅 ASD
data = data[data["dx"] == "ASD"]

# 去掉训练年龄段（>= 13 岁）
data = data[data["Age"] >= 13]

# 仅男性（主分析）
data = data[data["sex"] == "Male"]

print(f"✓ Subjects after filtering: {data.shape[0]}")

# =========================================================
# 5. 保存 ID / 元数据
# =========================================================

meta_cols = ["participant", "Site", "Release", "Age", "sex", "dx"]
meta_cols = [c for c in meta_cols if c in data.columns]

meta_data = data[meta_cols].copy()

# =========================================================
# 6. 构建特征矩阵
# =========================================================

X = data.drop(columns=meta_cols)

# 模型期望的特征（顺序非常重要）
model_features = loaded_model.best_estimator_.feature_names_in_

# 检查特征缺失
missing_features = set(model_features) - set(X.columns)
if len(missing_features) > 0:
    raise ValueError(
        "❌ 新数据缺少模型所需特征：\n"
        f"{missing_features}"
    )

# 按训练时顺序选取特征
X = X[model_features]

# =========================================================
# 直接删除含有NaN的行
# =========================================================

# 记录删除前的样本数
original_samples = X.shape[0]

# 删除所有包含NaN的行
nan_mask = X.isna().any(axis=1)
X = X[~nan_mask]
meta_data = meta_data.loc[~nan_mask]

print(f"删除 {nan_mask.sum()}/{original_samples} 个包含NaN的样本")
print(f"剩余 {X.shape[0]} 个样本")

print(f"✓ 特征矩阵 shape: {X.shape}")

# =========================================================
# 7. 分型预测
# =========================================================

predicted_cluster = loaded_model.predict(X)

# （可选）decision function，用于后续不确定性分析
decision_score = loaded_model.decision_function(X)

# =========================================================
# 8. 保存结果
# =========================================================

output_df = meta_data.copy()
output_df["predicted_cluster"] = predicted_cluster
output_df["decision_score"] = decision_score

output_df.to_csv(output_file, index=False)

print("✓ Cluster assignment completed")
print(f"✓ Results saved to:\n{output_file}")
