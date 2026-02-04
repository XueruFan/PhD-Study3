# -*- coding: utf-8 -*-
"""
Apply trained ABIDE SVM (5–12.9y ASD Male)
to ABIDE remaining subjects (>=13y ASD Male),
assign subtype = 0 to male controls only

@author: xueru
"""

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
    "abide_cluster_predictions_male.csv"
)

# =========================================================
# 2. 加载模型
# =========================================================

loaded_model = joblib.load(model_file)
print("✓ Trained SVM model loaded")

# =========================================================
# 3. 读取 ABIDE 全数据
# =========================================================

data_all = pd.read_csv(data_file)
print(f"✓ Original dataset size: {data_all.shape}")

# =========================================================
# 4. ASD 预测人群筛选（Male, Age ≥ 13）
# =========================================================

data_asd = data_all.copy()

data_asd = data_asd[
    (data_asd["dx"] == "ASD") &
    (data_asd["Age"] >= 13) &
    (data_asd["sex"] == "Male")
]

print(f"✓ ASD subjects for prediction: {data_asd.shape[0]}")

# =========================================================
# 5. ASD 元数据
# =========================================================

meta_cols = ["participant", "Site", "Release", "Age", "sex", "dx"]
meta_cols = [c for c in meta_cols if c in data_asd.columns]

meta_asd = data_asd[meta_cols].copy()

# =========================================================
# 6. 构建特征矩阵
# =========================================================

X = data_asd.drop(columns=meta_cols)

model_features = loaded_model.best_estimator_.feature_names_in_

missing_features = set(model_features) - set(X.columns)
if missing_features:
    raise ValueError(
        "❌ 新数据缺少模型所需特征：\n"
        f"{missing_features}"
    )

X = X[model_features]

# =========================================================
# 7. 删除包含 NaN 的 ASD 样本
# =========================================================

nan_mask = X.isna().any(axis=1)
print(f"删除 {nan_mask.sum()} 个包含 NaN 的 ASD 样本")

X = X[~nan_mask]
meta_asd = meta_asd.loc[~nan_mask]

print(f"✓ Remaining ASD samples: {X.shape[0]}")

# =========================================================
# 8. ASD 分型预测
# =========================================================

predicted_cluster = loaded_model.predict(X)
decision_score = loaded_model.decision_function(X)

asd_result = meta_asd.copy()
asd_result["subtype"] = predicted_cluster
asd_result["decision_score"] = decision_score

# =========================================================
# 9. 男性对照组（仅元数据，subtype = 0）
# =========================================================

control_result = data_all[
    (data_all["dx"] != "ASD") &
    (data_all["sex"] == "Male")
][meta_cols].copy()

control_result["subtype"] = 0
control_result["decision_score"] = 0.0

print(f"✓ Male control subjects: {control_result.shape[0]}")

# =========================================================
# 10. 合并 ASD + Control 并保存
# =========================================================

final_output = pd.concat(
    [asd_result, control_result],
    axis=0,
    ignore_index=True
)

final_output.to_csv(output_file, index=False)

print("✓ Cluster assignment completed (Male ASD + Male Control)")
print(f"✓ Results saved to:\n{output_file}")
