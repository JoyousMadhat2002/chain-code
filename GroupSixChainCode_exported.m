classdef GroupSixChainCode_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        Image4                         matlab.ui.control.Image
        Image3                         matlab.ui.control.Image
        Image2                         matlab.ui.control.Image
        Image                          matlab.ui.control.Image
        CompareEditField               matlab.ui.control.NumericEditField
        SimilarityLabel                matlab.ui.control.Label
        ComparetheTwoButton            matlab.ui.control.Button
        NormalizedChainCodeEditField2  matlab.ui.control.EditField
        NormalizedChainCode2Label      matlab.ui.control.Label
        DifferentatedChainCodeEditField2  matlab.ui.control.EditField
        DifferentatedChainCode2Label   matlab.ui.control.Label
        ChainCodeEditField2            matlab.ui.control.EditField
        ChainCode2Label                matlab.ui.control.Label
        NormalizedChainCodeEditField   matlab.ui.control.EditField
        NormalizedChainCodeEditFieldLabel  matlab.ui.control.Label
        DifferentatedChainCodeEditField  matlab.ui.control.EditField
        DifferentatedChainCodeEditFieldLabel  matlab.ui.control.Label
        ChainCodeEditField             matlab.ui.control.EditField
        ChainCodeEditFieldLabel        matlab.ui.control.Label
        SaveChainCodeButton2           matlab.ui.control.Button
        SaveChainCodeButton            matlab.ui.control.Button
        ExtractChainCodeButton2        matlab.ui.control.Button
        ExtractChainCodeButton         matlab.ui.control.Button
        ExtractFeaturesButton2         matlab.ui.control.Button
        ExtractFeaturesButton          matlab.ui.control.Button
        LoadImageButton2               matlab.ui.control.Button
        LoadImageButton                matlab.ui.control.Button
        TextArea2                      matlab.ui.control.TextArea
        TextArea_2Label                matlab.ui.control.Label
        TextArea                       matlab.ui.control.TextArea
        TextAreaLabel                  matlab.ui.control.Label
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadImageButton
        function LoadImageButtonPushed(app, event)
            % Load an image from files
            [file, path] = uigetfile({'*.jpg;*.png;*.jpeg;*.bmp;*.tif','Image Files'}, 'Select an image file');
            if isequal(file,0)
                disp('User selected Cancel')
            else
                % Read the selected image
                originalImage = imread(fullfile(path, file));
                % Display the image in Image
                app.Image.ImageSource = originalImage;
            end
        end

        % Button pushed function: ExtractFeaturesButton
        function ExtractFeaturesButtonPushed(app, event)
            % Get the image from app.Image
            originalImage = app.Image.ImageSource;

            % Check if the image is loaded
            if isempty(originalImage)
                uialert(app.UIFigure, 'No image loaded!', 'Error');
                return;
            end

            % Detect edges and thin them
            [~, thinnedEdgeImage] = detectEdges(originalImage);

            % Convert binary edge image to RGB format
            edgeRGB = uint8(255 * repmat(thinnedEdgeImage, [1, 1, 3]));
            % Logical → uint8 RGB

            % Display the thinned edges in app.Image2
            app.Image2.ImageSource = edgeRGB;

            % Nested function for edge detection
            function [edgeImage, thinnedEdgeImage] = detectEdges(image)
                % Convert to grayscale if RGB
                if size(image, 3) == 3
                    grayImage = rgb2gray(image);
                else
                    grayImage = image;
                end

                % Detect edges using Canny
                edgeImage = edge(grayImage, 'Canny');

                % Thin the edges to 1-pixel width
                thinnedEdgeImage = bwmorph(edgeImage, 'thin', Inf);
            end
        end

        % Button pushed function: ExtractChainCodeButton
        function ExtractChainCodeButtonPushed(app, event)
            thinnedEdgeImage = app.Image2.ImageSource;

            % Check if the image is empty
            if isempty(thinnedEdgeImage)
                uialert(app.UIFigure, 'No edge image found!', 'Error');
                return;
            end

            % Ensure the image is binary
            if ~islogical(thinnedEdgeImage)
                thinnedEdgeImage = imbinarize(rgb2gray(thinnedEdgeImage));
            end

            % Step 1: Extract Chain Code
            chainCode = traverseBoundaryWithCodes(thinnedEdgeImage);
            chainCodeStr = num2str(chainCode);
            app.ChainCodeEditField.Value = chainCodeStr;

            % Step 2: Differentiate Chain Code
            diffChainCode = differentiateChainCode(chainCode);
            diffChainCodeStr = num2str(diffChainCode);
            app.DifferentatedChainCodeEditField.Value = diffChainCodeStr;

            % Step 3: Normalize Chain Code
            normalizedCodes = normalizeChainCodes(diffChainCode);
            sortedCodes = sortrows(normalizedCodes);
            app.NormalizedChainCodeEditField.Value = num2str(sortedCodes(1, :));

            % Display normalizedCodes in TextArea
            normalizedCodesStr = '';
            for i = 1:size(normalizedCodes, 1)
                normalizedCodesStr = [normalizedCodesStr mat2str(sortedCodes(i, :)) newline];
            end
            app.TextArea.Value = normalizedCodesStr;

            function chainCode = traverseBoundaryWithCodes(thinnedEdgeImage)
                % Find the starting pixel (P0)
                [row, col] = find(thinnedEdgeImage, 1, 'first');
                startingPixel = [row, col];
                currentPixel = startingPixel;

                % Initialize direction
                DIR = 7;

                % Define directions
                directions = [0, -1; -1, -1; -1, 0; -1, 1; 0, 1; 1, 1; 1, 0; 1, -1];
                codeValues = [4, 3, 2, 1, 0, 5, 6, 7]; 
                % Corresponding values for directions

                % Traverse the boundary
                chainCode = [];
                while true
                    % Find the direction of the next white pixel
                    nextDir = mod(DIR + 7, 8);
                    found = false;
                    for i = 1:8
                        nextPixel = currentPixel + directions(nextDir + 1, :);
                        if thinnedEdgeImage(nextPixel(1), nextPixel(2))
                            found = true;
                            break;
                        else
                            nextDir = mod(nextDir + 1, 8);
                        end
                    end

                    % Break if the starting pixel is reached again and chainCode is not empty
                    if isequal(nextPixel, startingPixel) && ~isempty(chainCode)
                        break;
                    end

                    % Assign the code value
                    chainCode = [chainCode, codeValues(nextDir + 1)];

                    % Move to the next pixel
                    currentPixel = nextPixel;
                    DIR = nextDir;
                end
            end

            function diffChainCode = differentiateChainCode(chainCode)
                n = length(chainCode);
                diffChainCode = zeros(1, n);
                for k = 1:n
                    ck = chainCode(k);
                    ck_1 = chainCode(mod(k-2, n) + 1); % ck-1 (with wrapping)
                    diffChainCode(k) = mod(ck - ck_1, 8);
                end
            end

            function normalizedCodes = normalizeChainCodes(chainCode)
                n = length(chainCode);
                normalizedCodes = zeros(n, n);  % Preallocate matrix to store all permutations
                for i = 1:n
                    % Rotate the chain code to the left by i-1 positions
                    normalizedCodes(i, :) = circshift(chainCode, -i + 1);
                end
            end
        end

        % Button pushed function: SaveChainCodeButton
        function SaveChainCodeButtonPushed(app, event)
            % Get the necessary data from UI elements or app properties
            thinnedEdgeImage = app.Image2.ImageSource;

            % Check if the image is empty
            if isempty(thinnedEdgeImage)
                uialert(app.UIFigure, 'No edge image found!', 'Error');
                return;
            end

            % Ensure the image is binary (logical) for chain code extraction
            if ~islogical(thinnedEdgeImage)
                % Convert to binary if it's not already (e.g., if it's uint8 RGB)
                thinnedEdgeImage = imbinarize(rgb2gray(thinnedEdgeImage));
            end

            chainCodeStr = app.ChainCodeEditField.Value;
            diffChainCodeStr = app.DifferentatedChainCodeEditField.Value;
            normalizedChainCodeStr = app.NormalizedChainCodeEditField.Value;

            % Convert chain codes from strings to numerical arrays
            chainCode = str2num(chainCodeStr);
            diffChainCode = str2num(diffChainCodeStr);
            normalizedChainCode = str2num(normalizedChainCodeStr);

            % Get the normalized chain codes from the TextArea
            normalizedCodesStr = app.TextArea.Value;
            normalizedCodes = str2double(split(string(normalizedCodesStr)));

            % Get the desired output filename from the user
            outputFilename = inputdlg('Enter the output filename:', 'Save As', [1 50]);

            % Check if the user provided a filename
            if ~isempty(outputFilename)
                % Call the writeOutputsToFile function to save the data
                writeOutputsToFile(outputFilename{1}, thinnedEdgeImage, chainCode, diffChainCode, normalizedChainCode, normalizedCodes);
                % Provide feedback to the user that the data has been saved
                msgbox('Chain codes and images have been saved successfully', 'Save Successful', 'modal');
            else
                % Provide feedback to the user that saving was cancelled
                msgbox('Saving cancelled', 'Cancelled', 'warn', 'modal');
            end

            function writeOutputsToFile(filename, thinnedEdgeImage, chainCode, diffChainCode, normalizedChainCode, normalizedCodes)
                fid = fopen(filename, 'w');

                % Write thinned edge image dimensions
                fprintf(fid, 'Thinned Edge Image Dimensions:\n');
                fprintf(fid, 'Height: %d, Width: %d\n\n', size(thinnedEdgeImage, 1), size(thinnedEdgeImage, 2));

                % Write chain code
                fprintf(fid, 'Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(chainCode));

                % Write differential chain code
                fprintf(fid, 'Differential Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(diffChainCode));

                % Write normalized chain code
                fprintf(fid, 'Normalized Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(normalizedChainCode));

                % Write sorted normalized chain codes
                fprintf(fid, 'Sorted Normalized Chain Codes:\n');
                for i = 1:size(normalizedCodes, 1)
                    fprintf(fid, '%s\n', num2str(normalizedCodes(i, :)));
                end

                fclose(fid);
            end
        end

        % Button pushed function: LoadImageButton2
        function LoadImageButton2Pushed(app, event)
            % Load an image from files
            [file, path] = uigetfile({'*.jpg;*.png;*.jpeg;*.bmp;*.tif','Image Files'}, 'Select an image file');
            if isequal(file,0)
                disp('User selected Cancel')
            else
                % Read the selected image
                originalImage = imread(fullfile(path, file));
                % Display the image in Images
                app.Image3.ImageSource = originalImage;
            end
        end

        % Button pushed function: ExtractFeaturesButton2
        function ExtractFeaturesButton2Pushed(app, event)
            % Get the image from app.Image
            originalImage = app.Image3.ImageSource;

            % Check if the image is loaded
            if isempty(originalImage)
                uialert(app.UIFigure, 'No image loaded!', 'Error');
                return;
            end

            % Detect edges and thin them
            [~, thinnedEdgeImage] = detectEdges(originalImage);

            % Convert binary edge image to RGB format
            edgeRGB = uint8(255 * repmat(thinnedEdgeImage, [1, 1, 3]));
            % Logical → uint8 RGB

            % Display the thinned edges in app.Image2
            app.Image4.ImageSource = edgeRGB;

            % Nested function for edge detection
            function [edgeImage, thinnedEdgeImage] = detectEdges(image)
                % Convert to grayscale if RGB
                if size(image, 3) == 3
                    grayImage = rgb2gray(image);
                else
                    grayImage = image;
                end

                % Detect edges using Canny
                edgeImage = edge(grayImage, 'Canny');

                % Thin the edges to 1-pixel width
                thinnedEdgeImage = bwmorph(edgeImage, 'thin', Inf);
            end
        end

        % Button pushed function: ExtractChainCodeButton2
        function ExtractChainCodeButton2Pushed(app, event)
            thinnedEdgeImage = app.Image4.ImageSource;

            % Check if the image is empty
            if isempty(thinnedEdgeImage)
                uialert(app.UIFigure, 'No edge image found!', 'Error');
                return;
            end

            % Ensure the image is binary
            if ~islogical(thinnedEdgeImage)
                thinnedEdgeImage = imbinarize(rgb2gray(thinnedEdgeImage));
            end

            % Step 1: Extract Chain Code
            chainCode = traverseBoundaryWithCodes(thinnedEdgeImage);
            chainCodeStr = num2str(chainCode);
            app.ChainCodeEditField2.Value = chainCodeStr;

            % Step 2: Differentiate Chain Code
            diffChainCode = differentiateChainCode(chainCode);
            diffChainCodeStr = num2str(diffChainCode);
            app.DifferentatedChainCodeEditField2.Value = diffChainCodeStr;

            % Step 3: Normalize Chain Code
            normalizedCodes = normalizeChainCodes(diffChainCode);
            sortedCodes = sortrows(normalizedCodes);
            app.NormalizedChainCodeEditField2.Value = num2str(sortedCodes(1, :));

            % Display normalizedCodes in TextArea
            normalizedCodesStr = '';
            for i = 1:size(normalizedCodes, 1)
                normalizedCodesStr = [normalizedCodesStr mat2str(sortedCodes(i, :)) newline];
            end
            app.TextArea2.Value = normalizedCodesStr;

            function chainCode = traverseBoundaryWithCodes(thinnedEdgeImage)
                % Find the starting pixel (P0)
                [row, col] = find(thinnedEdgeImage, 1, 'first');
                startingPixel = [row, col];
                currentPixel = startingPixel;

                % Initialize direction
                DIR = 7;

                % Define directions
                directions = [0, -1; -1, -1; -1, 0; -1, 1; 0, 1; 1, 1; 1, 0; 1, -1];
                codeValues = [4, 3, 2, 1, 0, 5, 6, 7]; % Corresponding values for directions

                % Traverse the boundary
                chainCode = [];
                while true
                    % Find the direction of the next white pixel
                    nextDir = mod(DIR + 7, 8);
                    found = false;
                    for i = 1:8
                        nextPixel = currentPixel + directions(nextDir + 1, :);
                        if thinnedEdgeImage(nextPixel(1), nextPixel(2))
                            found = true;
                            break;
                        else
                            nextDir = mod(nextDir + 1, 8);
                        end
                    end

                    % Break if the starting pixel is reached again and chainCode is not empty
                    if isequal(nextPixel, startingPixel) && ~isempty(chainCode)
                        break;
                    end

                    % Assign the code value
                    chainCode = [chainCode, codeValues(nextDir + 1)];

                    % Move to the next pixel
                    currentPixel = nextPixel;
                    DIR = nextDir;
                end
            end

            function diffChainCode = differentiateChainCode(chainCode)
                n = length(chainCode);
                diffChainCode = zeros(1, n);
                for k = 1:n
                    ck = chainCode(k);
                    ck_1 = chainCode(mod(k-2, n) + 1); % ck-1 (with wrapping)
                    diffChainCode(k) = mod(ck - ck_1, 8);
                end
            end

            function normalizedCodes = normalizeChainCodes(chainCode)
                n = length(chainCode);
                normalizedCodes = zeros(n, n);  % Preallocate matrix to store all permutations
                for i = 1:n
                    % Rotate the chain code to the left by i-1 positions
                    normalizedCodes(i, :) = circshift(chainCode, -i + 1);
                end
            end
        end

        % Button pushed function: SaveChainCodeButton2
        function SaveChainCodeButton2Pushed(app, event)
            thinnedEdgeImage = app.Image4.ImageSource;

            % Check if the image is empty
            if isempty(thinnedEdgeImage)
                uialert(app.UIFigure, 'No edge image found!', 'Error');
                return;
            end

            % Ensure the image is binary
            if ~islogical(thinnedEdgeImage)
                thinnedEdgeImage = imbinarize(rgb2gray(thinnedEdgeImage));
            end

            chainCodeStr = app.ChainCodeEditField2.Value;
            diffChainCodeStr = app.DifferentatedChainCodeEditField2.Value;
            normalizedChainCodeStr = app.NormalizedChainCodeEditField2.Value;

            % Convert chain codes from strings to numerical arrays
            chainCode = str2num(chainCodeStr);
            diffChainCode = str2num(diffChainCodeStr);
            normalizedChainCode = str2num(normalizedChainCodeStr);

            % Get the normalized chain codes from the TextArea
            normalizedCodesStr = app.TextArea.Value;
            normalizedCodes = str2double(split(string(normalizedCodesStr)));

            % Get the desired output filename from the user
            outputFilename = inputdlg('Enter the output filename:', 'Save As', [1 50]);

            % Check if the user provided a filename
            if ~isempty(outputFilename)
                % Call the writeOutputsToFile function to save the data
                writeOutputsToFile(outputFilename{1}, thinnedEdgeImage, chainCode, diffChainCode, normalizedChainCode, normalizedCodes);
                % Provide feedback to the user that the data has been saved
                msgbox('Chain codes and images have been saved successfully', 'Save Successful', 'modal');
            else
                % Provide feedback to the user that saving was cancelled
                msgbox('Saving cancelled', 'Cancelled', 'warn', 'modal');
            end

            function writeOutputsToFile(filename, thinnedEdgeImage, chainCode, diffChainCode, normalizedChainCode, normalizedCodes)
                fid = fopen(filename, 'w');

                % Write thinned edge image dimensions
                fprintf(fid, 'Thinned Edge Image Dimensions:\n');
                fprintf(fid, 'Height: %d, Width: %d\n\n', size(thinnedEdgeImage, 1), size(thinnedEdgeImage, 2));

                % Write chain code
                fprintf(fid, 'Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(chainCode));

                % Write differential chain code
                fprintf(fid, 'Differential Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(diffChainCode));

                % Write normalized chain code
                fprintf(fid, 'Normalized Chain Code:\n');
                fprintf(fid, '%s\n\n', num2str(normalizedChainCode));

                % Write sorted normalized chain codes
                fprintf(fid, 'Sorted Normalized Chain Codes:\n');
                for i = 1:size(normalizedCodes, 1)
                    fprintf(fid, '%s\n', num2str(normalizedCodes(i, :)));
                end

                fclose(fid);
            end
        end

        % Button pushed function: ComparetheTwoButton
        function ComparetheTwoButtonPushed(app, event)
            % Get the normalized chain codes from both fields
            normalizedChainCode1 = str2num(app.NormalizedChainCodeEditField.Value);
            normalizedChainCode2 = str2num(app.NormalizedChainCodeEditField2.Value);

            % Check if both chain codes are available
            if isempty(normalizedChainCode1) || isempty(normalizedChainCode2)
                msgbox('Please extract chain codes for both images first.', 'Error', 'error');
                return;
            end

            % Check if the chain codes are of the same length
            if length(normalizedChainCode1) ~= length(normalizedChainCode2)
                msgbox('Chain codes must be of the same length to compare.', 'Error', 'error');
                return;
            end

            % Calculate the similarity
            matchingElements = sum(normalizedChainCode1 == normalizedChainCode2);
            totalElements = length(normalizedChainCode1);
            similarityPercentage = (matchingElements / totalElements) * 100;

            % Display the result in the EditField
            app.CompareEditField.Value = similarityPercentage;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 910 849];
            app.UIFigure.Name = 'MATLAB App';

            % Create TextAreaLabel
            app.TextAreaLabel = uilabel(app.UIFigure);
            app.TextAreaLabel.HorizontalAlignment = 'right';
            app.TextAreaLabel.Visible = 'off';
            app.TextAreaLabel.Position = [12 -87 55 22];
            app.TextAreaLabel.Text = 'Text Area';

            % Create TextArea
            app.TextArea = uitextarea(app.UIFigure);
            app.TextArea.Editable = 'off';
            app.TextArea.Visible = 'off';
            app.TextArea.Position = [82 -223 282 160];

            % Create TextArea_2Label
            app.TextArea_2Label = uilabel(app.UIFigure);
            app.TextArea_2Label.HorizontalAlignment = 'right';
            app.TextArea_2Label.Visible = 'off';
            app.TextArea_2Label.Position = [510 -89 55 22];
            app.TextArea_2Label.Text = 'Text Area';

            % Create TextArea2
            app.TextArea2 = uitextarea(app.UIFigure);
            app.TextArea2.Editable = 'off';
            app.TextArea2.Visible = 'off';
            app.TextArea2.Position = [580 -225 282 160];

            % Create LoadImageButton
            app.LoadImageButton = uibutton(app.UIFigure, 'push');
            app.LoadImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadImageButtonPushed, true);
            app.LoadImageButton.Position = [41 817 185 23];
            app.LoadImageButton.Text = 'Load Image';

            % Create LoadImageButton2
            app.LoadImageButton2 = uibutton(app.UIFigure, 'push');
            app.LoadImageButton2.ButtonPushedFcn = createCallbackFcn(app, @LoadImageButton2Pushed, true);
            app.LoadImageButton2.Position = [681 817 185 23];
            app.LoadImageButton2.Text = 'Load Image 2';

            % Create ExtractFeaturesButton
            app.ExtractFeaturesButton = uibutton(app.UIFigure, 'push');
            app.ExtractFeaturesButton.ButtonPushedFcn = createCallbackFcn(app, @ExtractFeaturesButtonPushed, true);
            app.ExtractFeaturesButton.Position = [41 784 185 23];
            app.ExtractFeaturesButton.Text = 'Extract Features';

            % Create ExtractFeaturesButton2
            app.ExtractFeaturesButton2 = uibutton(app.UIFigure, 'push');
            app.ExtractFeaturesButton2.ButtonPushedFcn = createCallbackFcn(app, @ExtractFeaturesButton2Pushed, true);
            app.ExtractFeaturesButton2.Position = [681 784 185 23];
            app.ExtractFeaturesButton2.Text = 'Extract Features';

            % Create ExtractChainCodeButton
            app.ExtractChainCodeButton = uibutton(app.UIFigure, 'push');
            app.ExtractChainCodeButton.ButtonPushedFcn = createCallbackFcn(app, @ExtractChainCodeButtonPushed, true);
            app.ExtractChainCodeButton.Position = [41 751 185 23];
            app.ExtractChainCodeButton.Text = 'Extract Chain Code';

            % Create ExtractChainCodeButton2
            app.ExtractChainCodeButton2 = uibutton(app.UIFigure, 'push');
            app.ExtractChainCodeButton2.ButtonPushedFcn = createCallbackFcn(app, @ExtractChainCodeButton2Pushed, true);
            app.ExtractChainCodeButton2.Position = [681 751 185 23];
            app.ExtractChainCodeButton2.Text = 'Extract Chain Code';

            % Create SaveChainCodeButton
            app.SaveChainCodeButton = uibutton(app.UIFigure, 'push');
            app.SaveChainCodeButton.ButtonPushedFcn = createCallbackFcn(app, @SaveChainCodeButtonPushed, true);
            app.SaveChainCodeButton.Position = [41 718 185 23];
            app.SaveChainCodeButton.Text = 'Save Chain Code';

            % Create SaveChainCodeButton2
            app.SaveChainCodeButton2 = uibutton(app.UIFigure, 'push');
            app.SaveChainCodeButton2.ButtonPushedFcn = createCallbackFcn(app, @SaveChainCodeButton2Pushed, true);
            app.SaveChainCodeButton2.Position = [681 718 185 23];
            app.SaveChainCodeButton2.Text = 'Save Chain Code';

            % Create ChainCodeEditFieldLabel
            app.ChainCodeEditFieldLabel = uilabel(app.UIFigure);
            app.ChainCodeEditFieldLabel.HorizontalAlignment = 'right';
            app.ChainCodeEditFieldLabel.Position = [61 664 105 23];
            app.ChainCodeEditFieldLabel.Text = 'Chain Code';

            % Create ChainCodeEditField
            app.ChainCodeEditField = uieditfield(app.UIFigure, 'text');
            app.ChainCodeEditField.Position = [194 665 206 22];

            % Create DifferentatedChainCodeEditFieldLabel
            app.DifferentatedChainCodeEditFieldLabel = uilabel(app.UIFigure);
            app.DifferentatedChainCodeEditFieldLabel.HorizontalAlignment = 'right';
            app.DifferentatedChainCodeEditFieldLabel.Position = [41 631 145 23];
            app.DifferentatedChainCodeEditFieldLabel.Text = 'Differentated Chain Code';

            % Create DifferentatedChainCodeEditField
            app.DifferentatedChainCodeEditField = uieditfield(app.UIFigure, 'text');
            app.DifferentatedChainCodeEditField.Position = [194 632 206 22];

            % Create NormalizedChainCodeEditFieldLabel
            app.NormalizedChainCodeEditFieldLabel = uilabel(app.UIFigure);
            app.NormalizedChainCodeEditFieldLabel.HorizontalAlignment = 'right';
            app.NormalizedChainCodeEditFieldLabel.Position = [41 598 145 23];
            app.NormalizedChainCodeEditFieldLabel.Text = 'Normalized Chain Code';

            % Create NormalizedChainCodeEditField
            app.NormalizedChainCodeEditField = uieditfield(app.UIFigure, 'text');
            app.NormalizedChainCodeEditField.Position = [194 599 206 22];

            % Create ChainCode2Label
            app.ChainCode2Label = uilabel(app.UIFigure);
            app.ChainCode2Label.HorizontalAlignment = 'right';
            app.ChainCode2Label.Position = [527 664 105 23];
            app.ChainCode2Label.Text = 'Chain Code 2';

            % Create ChainCodeEditField2
            app.ChainCodeEditField2 = uieditfield(app.UIFigure, 'text');
            app.ChainCodeEditField2.Position = [660 665 206 22];

            % Create DifferentatedChainCode2Label
            app.DifferentatedChainCode2Label = uilabel(app.UIFigure);
            app.DifferentatedChainCode2Label.HorizontalAlignment = 'right';
            app.DifferentatedChainCode2Label.Position = [504 632 150 22];
            app.DifferentatedChainCode2Label.Text = 'Differentated Chain Code 2';

            % Create DifferentatedChainCodeEditField2
            app.DifferentatedChainCodeEditField2 = uieditfield(app.UIFigure, 'text');
            app.DifferentatedChainCodeEditField2.Position = [659 632 207 22];

            % Create NormalizedChainCode2Label
            app.NormalizedChainCode2Label = uilabel(app.UIFigure);
            app.NormalizedChainCode2Label.HorizontalAlignment = 'right';
            app.NormalizedChainCode2Label.Position = [507 600 145 22];
            app.NormalizedChainCode2Label.Text = 'Normalized Chain Code 2';

            % Create NormalizedChainCodeEditField2
            app.NormalizedChainCodeEditField2 = uieditfield(app.UIFigure, 'text');
            app.NormalizedChainCodeEditField2.Position = [660 600 206 22];

            % Create ComparetheTwoButton
            app.ComparetheTwoButton = uibutton(app.UIFigure, 'push');
            app.ComparetheTwoButton.ButtonPushedFcn = createCallbackFcn(app, @ComparetheTwoButtonPushed, true);
            app.ComparetheTwoButton.Position = [411 798 109 22];
            app.ComparetheTwoButton.Text = 'Compare the Two';

            % Create SimilarityLabel
            app.SimilarityLabel = uilabel(app.UIFigure);
            app.SimilarityLabel.HorizontalAlignment = 'right';
            app.SimilarityLabel.Position = [343 749 68 22];
            app.SimilarityLabel.Text = 'Similarity %';

            % Create CompareEditField
            app.CompareEditField = uieditfield(app.UIFigure, 'numeric');
            app.CompareEditField.Position = [426 739 163 41];

            % Create Image
            app.Image = uiimage(app.UIFigure);
            app.Image.Position = [44 371 334 200];

            % Create Image2
            app.Image2 = uiimage(app.UIFigure);
            app.Image2.Position = [44 111 334 200];

            % Create Image3
            app.Image3 = uiimage(app.UIFigure);
            app.Image3.Position = [551 370 334 200];

            % Create Image4
            app.Image4 = uiimage(app.UIFigure);
            app.Image4.Position = [551 110 334 200];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = GroupSixChainCode_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end