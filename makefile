PYTHON ?= py -3.7

OBJECT_DETECTION_LIB ?= models/research/object_detection
DATASET_DIR ?= d:/datasets/AudioLabs_v2
PIPELINE_CONFIG ?= configs/ssd.config
INIT = $(OBJECT_DETECTION_LIB) $(PIPELINE_CONFIG)

SCRIPTS_DIR ?= scripts
TRAIN_DIR ?= data/train
PB_DIR ?= data/output_pb
TFLITE_DIR ?= data/output_tflite
TFLITE_MODEL ?= model.tflite

test: $(INIT)
	$(PYTHON) $(OBJECT_DETECTION_LIB)/builders/model_builder_test.py

prepare-dataset: $(INIT)
	$(PYTHON) $(SCRIPTS_DIR)/prepare_dataset.py $(DATASET_DIR)
	$(PYTHON) $(SCRIPTS_DIR)/create_tf_records.py \
		--label_map_path="mapping.pbtxt" \
		--included_classes="system_measures" \
		--image_directory="$(DATASET_DIR)/dataset" \
		--annotation_directory="$(DATASET_DIR)/dataset" \
		--output_path_training_split="$(DATASET_DIR)/all/training.record" \
		--output_path_validation_split="$(DATASET_DIR)/all/validation.record" \
		--output_path_test_split="$(DATASET_DIR)/all/test.record"
	$(PYTHON) $(SCRIPTS_DIR)/modify_config.py \
		--pipeline_config="$(PIPELINE_CONFIG)" \
		--dataset_directory="$(DATASET_DIR)" \
		--mapping="mapping.pbtxt"

train: $(INIT)
	$(PYTHON) $(OBJECT_DETECTION_LIB)/model_main_tf2.py \
		--pipeline_config_path="$(PIPELINE_CONFIG)" \
		--model_dir="$(TRAIN_DIR)" \
		--alsologtostderr

evaluate: $(INIT) $(TRAIN_DIR)
	$(PYTHON) $(OBJECT_DETECTION_LIB)/model_main_tf2.py \
		--pipeline_config_path="$(PIPELINE_CONFIG)" \
		--model_dir="$(TRAIN_DIR)" \
		--checkpoint_dir="$(TRAIN_DIR)" \
		--alsologtostderr

freeze-pb: $(INIT) $(TRAIN_DIR)
	$(PYTHON) $(OBJECT_DETECTION_LIB)/exporter_main_v2.py \
		--input_type=image_tensor \
		--pipeline_config_path="$(PIPELINE_CONFIG)" \
		--trained_checkpoint_dir="$(TRAIN_DIR)" \
		--output_directory="$(PB_DIR)"

convert-tfjs: $(INIT) $(TRAIN_DIR)
	tensorflowjs_converter \
		--input_format=tf_saved_model \
		--output_node_names="predictions" \
		--saved_model_tags=serve \
		$(PB_DIR)/saved_model \
		$(PB_DIR)/web_model2

inference-pb: $(INIT) $(PB_DIR)
	$(PYTHON) $(SCRIPTS_DIR)/pb_inference.py $(PB_DIR)/saved_model

inference-tflite: $(TFLITE_MODEL)
	$(PYTHON) $(SCRIPTS_DIR)/tflite_inference.py $(TFLITE_MODEL)
