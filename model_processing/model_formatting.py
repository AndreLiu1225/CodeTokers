import onnx
from onnx_tf.backend import prepare

onnx_path = "model_processing/yolo11n.onnx"

onnx_model = onnx.load(onnx_path)
tf_rep = prepare(onnx_model)

pb_path = "yolo11n.pb"
tf_rep.export_graph(pb_path)